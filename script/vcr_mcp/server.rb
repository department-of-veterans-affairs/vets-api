#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'jmespath'
require_relative 'inspector'
require_relative 'spec_finder'
require_relative 'service_config'
require_relative 'preparation_guide'
require_relative 'validator'
require_relative 'ssl_patcher'

$stdout.sync = true
$stderr.sync = true

def log(message)
  warn "[VCR MCP] #{message}"
end

def vcr_inspect_tool_schema
  {
    name: 'vcr_inspect_cassette',
    description: 'Inspect the contents of a VCR cassette file to see recorded HTTP interactions.',
    inputSchema: {
      type: 'object',
      properties: {
        cassette_path: {
          type: 'string',
          description: 'The path or partial name of the cassette to inspect ' \
                       "(e.g., 'mhv_account_type_service/premium')."
        },
        query: {
          type: 'string',
          description: 'Optional JMESPath query to filter the cassette content ' \
                       "(e.g., 'interactions[].response.body.json.entry[].resource.id')."
        }
      },
      required: ['cassette_path']
    }
  }
end

def vcr_json_structure_tool_schema
  {
    name: 'vcr_json_structure',
    description: vcr_json_structure_description,
    inputSchema: vcr_json_structure_input_schema
  }
end

def vcr_json_structure_description
  'Extract the key structure (schema) of JSON responses from a VCR cassette. ' \
    'Useful for understanding the shape of data and constructing JMESPath queries. ' \
    'Shows keys, types, and array item structures without actual values.'
end

def vcr_json_structure_input_schema
  {
    type: 'object',
    properties: vcr_json_structure_properties,
    required: ['cassette_path']
  }
end

def vcr_json_structure_properties
  {
    cassette_path: {
      type: 'string',
      description: "The path or partial name of the cassette to analyze (e.g., 'mhv_account_type_service/premium')."
    },
    interaction_index: {
      type: 'integer',
      description: 'Optional index of specific interaction to analyze (0-based). If omitted, analyzes all.'
    },
    max_depth: {
      type: 'integer',
      description: 'Maximum depth to traverse (default: 10). Use to limit output for deeply nested structures.'
    },
    include_request: {
      type: 'boolean',
      description: 'Include request body structure (default: false, only response is shown).'
    }
  }
end

def vcr_find_specs_tool_schema
  {
    name: 'vcr_find_specs',
    description: 'Find spec files that use a given VCR cassette. Returns file paths, line numbers, and context.',
    inputSchema: {
      type: 'object',
      properties: {
        cassette_path: {
          type: 'string',
          description: 'The cassette name to search for (e.g., "rx_client/prescriptions/get_all_rxs").'
        }
      },
      required: ['cassette_path']
    }
  }
end

def vcr_prepare_rerecord_tool_schema
  {
    name: 'vcr_prepare_rerecord',
    description: vcr_prepare_rerecord_description,
    inputSchema: vcr_prepare_rerecord_input_schema
  }
end

def vcr_prepare_rerecord_description
  'Analyze a VCR cassette and generate step-by-step instructions for re-recording. ' \
    'Outputs commands to run - does not execute them or handle credentials directly. ' \
    'Detects the service, finds specs, and generates tunnel/settings configuration.'
end

def vcr_prepare_rerecord_input_schema
  {
    type: 'object',
    properties: {
      cassette_path: {
        type: 'string',
        description: 'The cassette to prepare for re-recording.'
      },
      environment: {
        type: 'string',
        enum: %w[staging dev prod],
        description: 'Target environment for settings/credentials (default: staging).'
      }
    },
    required: ['cassette_path']
  }
end

def vcr_validate_cassette_tool_schema
  {
    name: 'vcr_validate_cassette',
    description: 'Validate a VCR cassette for sensitive data (ICN, SSN, tokens, PII). ' \
                 'Checks for patterns that should be filtered before committing. ' \
                 'Also compares with the git HEAD version if the file has uncommitted changes.',
    inputSchema: {
      type: 'object',
      properties: {
        cassette_path: {
          type: 'string',
          description: 'The cassette to validate.'
        }
      },
      required: ['cassette_path']
    }
  }
end

def vcr_patch_ssl_tool_schema
  {
    name: 'vcr_patch_ssl',
    description: 'Temporarily patch a service configuration file to disable SSL verification for VCR re-recording. ' \
                 'Adds `conn.ssl.verify = false` to Faraday connection blocks. Creates a backup file. ' \
                 'Use vcr_unpatch_ssl to restore after recording.',
    inputSchema: {
      type: 'object',
      properties: {
        file_path: {
          type: 'string',
          description: 'Path to the configuration file to patch (e.g., "lib/unified_health_data/configuration.rb").'
        },
        cassette_path: {
          type: 'string',
          description: 'Alternatively, provide a cassette path to auto-detect and patch the relevant configuration.'
        }
      },
      required: []
    }
  }
end

def vcr_unpatch_ssl_tool_schema
  {
    name: 'vcr_unpatch_ssl',
    description: 'Remove SSL verification patches and restore original configuration files. ' \
                 'Use after VCR re-recording is complete.',
    inputSchema: {
      type: 'object',
      properties: {
        file_path: {
          type: 'string',
          description: 'Specific file to unpatch. If omitted, unpatches all patched files.'
        }
      },
      required: []
    }
  }
end

def vcr_list_ssl_patches_tool_schema
  {
    name: 'vcr_list_ssl_patches',
    description: 'List all configuration files currently patched for SSL bypass.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: []
    }
  }
end

def handle_list_tools
  {
    tools: [
      vcr_inspect_tool_schema,
      vcr_json_structure_tool_schema,
      vcr_find_specs_tool_schema,
      vcr_prepare_rerecord_tool_schema,
      vcr_validate_cassette_tool_schema,
      vcr_patch_ssl_tool_schema,
      vcr_unpatch_ssl_tool_schema,
      vcr_list_ssl_patches_tool_schema
    ]
  }
end

def format_body(body)
  return '<NO BODY>' if body.nil?

  if body[:is_json]
    JSON.pretty_generate(body[:json])
  elsif body[:is_image]
    "<IMAGE: #{body[:image_type]}>"
  else
    body[:raw]
  end
end

def format_interaction(interaction, idx)
  text = "#{'=' * 80}\n"
  text += "INTERACTION #{idx + 1} (Recorded: #{interaction[:recorded_at]})\n"
  text += "#{'=' * 80}\n"

  req = interaction[:request]
  text += "REQUEST:\n"
  text += "  #{req[:method].upcase} #{req[:uri]}\n"
  text += "  Headers: #{JSON.generate(req[:headers])}\n"
  text += "  Body:\n"
  text += "#{format_body(req[:body]).gsub(/^/, '    ')}\n"

  res = interaction[:response]
  text += "#{'-' * 80}\n"
  text += "RESPONSE:\n"
  text += "  Status: #{res[:status][:code]} #{res[:status][:message]}\n"
  text += "  Headers: #{JSON.generate(res[:headers])}\n"
  text += "  Body:\n"
  text += "#{format_body(res[:body]).gsub(/^/, '    ')}\n\n"

  text
end

def format_cassette_output(path, result)
  text_output = "Cassette: #{path}\n"
  text_output += "Interactions: #{result[:interactions].length}\n\n"

  result[:interactions].each_with_index do |interaction, idx|
    text_output += format_interaction(interaction, idx)
  end

  { content: [{ type: 'text', text: text_output }] }
end

def handle_error_result(result)
  {
    isError: true,
    content: [
      {
        type: 'text',
        text: result[:error] + (result[:matches] ? "\nMatches:\n#{result[:matches].join("\n")}" : '')
      }
    ]
  }
end

def handle_query_result(result, query)
  json_data = JSON.parse(result.to_json)
  query_result = JMESPath.search(query, json_data)
  { content: [{ type: 'text', text: JSON.pretty_generate(query_result) }] }
rescue => e
  { isError: true, content: [{ type: 'text', text: "JMESPath Error: #{e.message}" }] }
end

# Extracts the structure/schema of a JSON object showing keys and types
def extract_json_structure(obj, depth = 0, max_depth = 10)
  return '...' if depth >= max_depth

  case obj
  when Hash
    extract_hash_structure(obj, depth, max_depth)
  when Array
    extract_array_structure(obj, depth, max_depth)
  else
    extract_primitive_type(obj)
  end
end

def extract_hash_structure(obj, depth, max_depth)
  return '{}' if obj.empty?

  obj.transform_values { |value| extract_json_structure(value, depth + 1, max_depth) }
end

def extract_array_structure(obj, depth, max_depth)
  return '[]' if obj.empty?

  sample_structures = obj.take(3).map { |item| extract_json_structure(item, depth + 1, max_depth) }

  if sample_structures.uniq.length == 1
    ["#{sample_structures.first} (#{obj.length} items)"]
  else
    ["(#{obj.length} items, varied structure)", *sample_structures.uniq]
  end
end

def extract_primitive_type(obj)
  case obj
  when String then 'String'
  when Integer then 'Integer'
  when Float then 'Float'
  when TrueClass, FalseClass then 'Boolean'
  when NilClass then 'null'
  else obj.class.to_s
  end
end

def format_structure(structure, indent = 0)
  case structure
  when Hash
    format_hash_structure(structure, indent)
  when Array
    format_array_structure(structure, indent)
  else
    structure.to_s
  end
end

def format_hash_structure(structure, indent)
  return '{}' if structure.empty?

  lines = ['{']
  structure.each do |key, value|
    formatted_value = format_structure(value, indent + 2)
    lines << "#{' ' * (indent + 2)}#{key.to_s.inspect}: #{formatted_value}"
  end
  lines << "#{' ' * indent}}"
  lines.join("\n")
end

def format_array_structure(structure, indent)
  return '[]' if structure.empty?

  if structure.length == 1
    "[#{format_structure(structure.first, indent)}]"
  else
    lines = ['[']
    structure.each do |item|
      formatted = format_structure(item, indent + 2)
      lines << "#{' ' * (indent + 2)}#{formatted}"
    end
    lines << "#{' ' * indent}]"
    lines.join("\n")
  end
end

def handle_vcr_json_structure(path, interaction_index, max_depth, include_request)
  result = VcrMcp::Inspector.inspect(path, json: true)
  return handle_error_result(result) if result[:error]

  max_depth ||= 10
  interactions = validate_and_filter_interactions(result[:interactions], interaction_index)
  return interactions if interactions.is_a?(Hash) && interactions[:isError]

  text_output = build_json_structure_header(path, result[:interactions].length, max_depth)
  text_output += build_interactions_output(interactions, interaction_index, max_depth, include_request)

  { content: [{ type: 'text', text: text_output }] }
end

def validate_and_filter_interactions(interactions, interaction_index)
  return interactions unless interaction_index

  if interaction_index.negative? || interaction_index >= interactions.length
    msg = "Invalid interaction index: #{interaction_index}. " \
          "Cassette has #{interactions.length} interactions (0-#{interactions.length - 1})."
    return { isError: true, content: [{ type: 'text', text: msg }] }
  end

  [interactions[interaction_index]]
end

def build_json_structure_header(path, total_interactions, max_depth)
  "JSON Structure for: #{path}\n" \
    "Total interactions: #{total_interactions}\n" \
    "Max depth: #{max_depth}\n\n"
end

def build_interactions_output(interactions, interaction_index, max_depth, include_request)
  interactions.each_with_index.map do |interaction, idx|
    actual_idx = interaction_index || idx
    build_single_interaction_output(interaction, actual_idx, max_depth, include_request)
  end.join
end

def build_single_interaction_output(interaction, actual_idx, max_depth, include_request)
  req = interaction[:request]
  res = interaction[:response]

  output = build_interaction_header(req, res, actual_idx)
  output += build_request_structure(req, max_depth) if include_request
  output += build_response_structure(res, max_depth, actual_idx)
  output
end

def build_interaction_header(req, res, actual_idx)
  "#{'=' * 80}\n" \
    "INTERACTION #{actual_idx + 1}: #{req[:method].upcase} #{req[:uri]}\n" \
    "Status: #{res[:status][:code]} #{res[:status][:message]}\n" \
    "#{'=' * 80}\n\n"
end

def build_request_structure(req, max_depth)
  return '' unless req[:body]&.dig(:is_json)

  structure = extract_json_structure(req[:body][:json], 0, max_depth)
  "REQUEST BODY STRUCTURE:\n#{format_structure(structure, 0)}\n\n"
end

def build_response_structure(res, max_depth, actual_idx)
  if res[:body]&.dig(:is_json)
    structure = extract_json_structure(res[:body][:json], 0, max_depth)
    "RESPONSE BODY STRUCTURE:\n#{format_structure(structure, 0)}\n\n" \
      "JMESPATH HINTS:\n#{generate_jmespath_hints(res[:body][:json], actual_idx)}\n"
  elsif res[:body]
    "RESPONSE: Not JSON (#{res[:body][:is_image] ? 'Image' : 'Other format'})\n\n"
  else
    "RESPONSE: No body\n\n"
  end
end

def generate_jmespath_hints(json, interaction_idx)
  prefix = "interactions[#{interaction_idx}].response.body.json"
  hints = build_jmespath_hints_for_type(json, prefix)
  hints.take(10).join("\n")
end

def build_jmespath_hints_for_type(json, prefix)
  case json
  when Hash then build_hash_jmespath_hints(json, prefix)
  when Array then build_array_jmespath_hints(json, prefix)
  else []
  end
end

def build_hash_jmespath_hints(json, prefix)
  hints = []
  json.each_key do |key|
    hints << "  #{prefix}.#{key}"
    hints.concat(build_nested_array_hints(json[key], prefix, key))
  end
  hints
end

def build_nested_array_hints(value, prefix, key)
  return [] unless value.is_a?(Array) && !value.empty?

  hints = ["  #{prefix}.#{key}[]"]
  return hints unless value.first.is_a?(Hash)

  value.first.keys.take(3).each { |subkey| hints << "  #{prefix}.#{key}[].#{subkey}" }
  hints
end

def build_array_jmespath_hints(json, prefix)
  hints = ["  #{prefix}[]"]
  return hints unless json.first.is_a?(Hash)

  json.first.keys.take(5).each { |key| hints << "  #{prefix}[].#{key}" }
  hints
end

def handle_vcr_inspect(path, query)
  result = VcrMcp::Inspector.inspect(path, json: true)

  return handle_error_result(result) if result[:error]
  return handle_query_result(result, query) if query

  format_cassette_output(path, result)
end

def handle_vcr_find_specs(cassette_path)
  result = VcrMcp::SpecFinder.find(cassette_path)

  if result[:specs].empty?
    text = "No specs found using cassette '#{cassette_path}'.\n\n"
    text += "Try searching manually:\n"
    text += "  grep -r \"#{cassette_path}\" spec/ modules/*/spec/\n"
  else
    text = "Found #{result[:count]} spec(s) using cassette '#{cassette_path}':\n\n"
    result[:specs].each_with_index do |spec, idx|
      text += "#{idx + 1}. #{spec[:file]}:#{spec[:line]}\n"
      text += "   #{spec[:content]}\n\n"
    end
  end

  { content: [{ type: 'text', text: }] }
end

def handle_vcr_prepare_rerecord(cassette_path, environment)
  environment ||= 'staging'
  result = VcrMcp::PreparationGuide.generate(cassette_path, environment:)

  return handle_error_result(result) if result[:error]

  { content: [{ type: 'text', text: result[:guide] }] }
end

def handle_vcr_validate_cassette(cassette_path)
  result = VcrMcp::Validator.validate(cassette_path)

  return { isError: true, content: [{ type: 'text', text: result[:error] }] } if result[:error]

  { content: [{ type: 'text', text: result[:report] }] }
end

def handle_vcr_patch_ssl(file_path, cassette_path)
  result = execute_ssl_patch(file_path, cassette_path)
  return result if result[:isError]

  format_ssl_patch_result(result[:result])
end

def execute_ssl_patch(file_path, cassette_path)
  if file_path
    { result: VcrMcp::SslPatcher.patch_file(file_path) }
  elsif cassette_path
    { result: VcrMcp::SslPatcher.patch_for_cassette(cassette_path) }
  else
    { isError: true, content: [{ type: 'text', text: 'Either file_path or cassette_path is required.' }] }
  end
end

def format_ssl_patch_result(result)
  if result[:error]
    text = "Error: #{result[:error]}"
    text += "\nSuggestion: #{result[:suggestion]}" if result[:suggestion]
    return { isError: !result[:already_patched], content: [{ type: 'text', text: }] }
  end

  text = result[:results] ? format_multiple_patches(result) : format_single_patch(result)
  { content: [{ type: 'text', text: }] }
end

def format_multiple_patches(result)
  text = "SSL patches applied for service: #{result[:service]}\n\nPatched files:\n"
  result[:patched_files].each { |f| text += "  ✓ #{f}\n" }
  text += "\nTo restore after recording:\n  Use vcr_unpatch_ssl tool\n"
  text += "  Or: git checkout #{result[:patched_files].join(' ')}\n"
  text
end

def format_single_patch(result)
  "✓ #{result[:message]}\n\nBackup saved to: #{result[:backup]}\n\n" \
    "To restore after recording:\n  Use vcr_unpatch_ssl tool\n" \
    "  Or: git checkout #{result[:file]}\n"
end

def handle_vcr_unpatch_ssl(file_path)
  if file_path
    result = VcrMcp::SslPatcher.unpatch_file(file_path)
    return { isError: true, content: [{ type: 'text', text: "Error: #{result[:error]}" }] } if result[:error]

    text = "✓ #{result[:message]}"
  else
    result = VcrMcp::SslPatcher.unpatch_all
    if result[:unpatched].empty? && result[:errors].empty?
      text = 'No patched files found.'
    else
      text = "Unpatched files:\n"
      result[:unpatched].each { |f| text += "  ✓ #{f}\n" }
      if result[:errors].any?
        text += "\nErrors:\n"
        result[:errors].each { |e| text += "  ✗ #{e}\n" }
      end
    end
  end

  { content: [{ type: 'text', text: }] }
end

def handle_vcr_list_ssl_patches
  result = VcrMcp::SslPatcher.list_patched_files

  if result[:count].zero?
    text = 'No configuration files are currently patched for SSL bypass.'
  else
    text = "Currently patched files (#{result[:count]}):\n\n"
    result[:files].each { |f| text += "  • #{f}\n" }
    text += "\nUse vcr_unpatch_ssl to restore these files."
  end

  { content: [{ type: 'text', text: }] }
end

TOOL_HANDLERS = {
  'vcr_inspect_cassette' => ->(args) { handle_vcr_inspect(args['cassette_path'], args['query']) },
  'vcr_json_structure' => lambda { |args|
    handle_vcr_json_structure(
      args['cassette_path'], args['interaction_index'], args['max_depth'], args['include_request']
    )
  },
  'vcr_find_specs' => ->(args) { handle_vcr_find_specs(args['cassette_path']) },
  'vcr_prepare_rerecord' => ->(args) { handle_vcr_prepare_rerecord(args['cassette_path'], args['environment']) },
  'vcr_validate_cassette' => ->(args) { handle_vcr_validate_cassette(args['cassette_path']) },
  'vcr_patch_ssl' => ->(args) { handle_vcr_patch_ssl(args['file_path'], args['cassette_path']) },
  'vcr_unpatch_ssl' => ->(args) { handle_vcr_unpatch_ssl(args['file_path']) },
  'vcr_list_ssl_patches' => ->(_args) { handle_vcr_list_ssl_patches }
}.freeze

def handle_call_tool(name, arguments)
  handler = TOOL_HANDLERS[name]
  raise "Unknown tool: #{name}" unless handler

  handler.call(arguments)
end

log 'Starting VCR MCP Server...'

while (line = $stdin.gets)
  begin
    request = JSON.parse(line)
    # log "Received: #{request['method']}"

    response = {
      jsonrpc: '2.0',
      id: request['id']
    }

    case request['method']
    when 'initialize'
      response[:result] = {
        protocolVersion: '2024-11-05',
        capabilities: {
          tools: {}
        },
        serverInfo: {
          name: 'vets-api-vcr',
          version: '1.0.0'
        }
      }
    when 'tools/list'
      response[:result] = handle_list_tools
    when 'tools/call'
      params = request['params']
      response[:result] = handle_call_tool(params['name'], params['arguments'])
    else
      # No response needed for notifications or unknown methods
      next
    end

    puts JSON.generate(response)
    $stdout.flush
  rescue => e
    log "Error: #{e.message}"
    log e.backtrace.join("\n")
  end
end
