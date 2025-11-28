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
    description: 'Extract the key structure (schema) of JSON responses from a VCR cassette. ' \
                 'Useful for understanding the shape of data and constructing JMESPath queries. ' \
                 'Shows keys, types, and array item structures without actual values.',
    inputSchema: {
      type: 'object',
      properties: {
        cassette_path: {
          type: 'string',
          description: 'The path or partial name of the cassette to analyze ' \
                       "(e.g., 'mhv_account_type_service/premium')."
        },
        interaction_index: {
          type: 'integer',
          description: 'Optional index of specific interaction to analyze (0-based). ' \
                       'If omitted, analyzes all interactions.'
        },
        max_depth: {
          type: 'integer',
          description: 'Maximum depth to traverse (default: 10). Use to limit output for deeply nested structures.'
        },
        include_request: {
          type: 'boolean',
          description: 'Include request body structure (default: false, only response is shown).'
        }
      },
      required: ['cassette_path']
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
    description: 'Analyze a VCR cassette and generate step-by-step instructions for re-recording. ' \
                 'Outputs commands to run - does not execute them or handle credentials directly. ' \
                 'Detects the service, finds specs, and generates tunnel/settings configuration.',
    inputSchema: {
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
    return '{}' if obj.empty?

    structure = obj.each_with_object({}) do |(key, value), result|
      result[key] = extract_json_structure(value, depth + 1, max_depth)
    end
    structure
  when Array
    return '[]' if obj.empty?

    # Sample first few items to detect consistent structure
    sample_structures = obj.take(3).map { |item| extract_json_structure(item, depth + 1, max_depth) }

    # If all samples have same structure, show as single array item
    if sample_structures.uniq.length == 1
      ["#{sample_structures.first} (#{obj.length} items)"]
    else
      # Show varied structures
      ["(#{obj.length} items, varied structure)", *sample_structures.uniq]
    end
  when String
    'String'
  when Integer
    'Integer'
  when Float
    'Float'
  when TrueClass, FalseClass
    'Boolean'
  when NilClass
    'null'
  else
    obj.class.to_s
  end
end

def format_structure(structure, indent = 0)
  case structure
  when Hash
    return '{}' if structure.empty?

    lines = ['{']
    structure.each do |key, value|
      formatted_value = format_structure(value, indent + 2)
      if formatted_value.include?("\n")
        lines << "#{' ' * (indent + 2)}#{key.to_s.inspect}: #{formatted_value}"
      else
        lines << "#{' ' * (indent + 2)}#{key.to_s.inspect}: #{formatted_value}"
      end
    end
    lines << "#{' ' * indent}}"
    lines.join("\n")
  when Array
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
  else
    structure.to_s
  end
end

def handle_vcr_json_structure(path, interaction_index, max_depth, include_request)
  result = VcrMcp::Inspector.inspect(path, json: true)

  return handle_error_result(result) if result[:error]

  max_depth ||= 10
  interactions = result[:interactions]

  if interaction_index
    if interaction_index < 0 || interaction_index >= interactions.length
      return {
        isError: true,
        content: [{ type: 'text', text: "Invalid interaction index: #{interaction_index}. " \
                                        "Cassette has #{interactions.length} interactions (0-#{interactions.length - 1})." }]
      }
    end
    interactions = [interactions[interaction_index]]
  end

  text_output = "JSON Structure for: #{path}\n"
  text_output += "Total interactions: #{result[:interactions].length}\n"
  text_output += "Max depth: #{max_depth}\n\n"

  interactions.each_with_index do |interaction, idx|
    actual_idx = interaction_index || idx
    req = interaction[:request]
    res = interaction[:response]

    text_output += "#{'=' * 80}\n"
    text_output += "INTERACTION #{actual_idx + 1}: #{req[:method].upcase} #{req[:uri]}\n"
    text_output += "Status: #{res[:status][:code]} #{res[:status][:message]}\n"
    text_output += "#{'=' * 80}\n\n"

    if include_request && req[:body] && req[:body][:is_json]
      text_output += "REQUEST BODY STRUCTURE:\n"
      structure = extract_json_structure(req[:body][:json], 0, max_depth)
      text_output += format_structure(structure, 0)
      text_output += "\n\n"
    end

    if res[:body] && res[:body][:is_json]
      text_output += "RESPONSE BODY STRUCTURE:\n"
      structure = extract_json_structure(res[:body][:json], 0, max_depth)
      text_output += format_structure(structure, 0)
      text_output += "\n\n"

      # Add helpful JMESPath hints
      text_output += "JMESPATH HINTS:\n"
      text_output += generate_jmespath_hints(res[:body][:json], actual_idx)
      text_output += "\n"
    elsif res[:body]
      text_output += "RESPONSE: Not JSON (#{res[:body][:is_image] ? 'Image' : 'Other format'})\n\n"
    else
      text_output += "RESPONSE: No body\n\n"
    end
  end

  { content: [{ type: 'text', text: text_output }] }
end

def generate_jmespath_hints(json, interaction_idx)
  hints = []
  prefix = "interactions[#{interaction_idx}].response.body.json"

  case json
  when Hash
    json.each_key do |key|
      hints << "  #{prefix}.#{key}"
      if json[key].is_a?(Array) && !json[key].empty?
        hints << "  #{prefix}.#{key}[]"
        if json[key].first.is_a?(Hash)
          json[key].first.keys.take(3).each do |subkey|
            hints << "  #{prefix}.#{key}[].#{subkey}"
          end
        end
      end
    end
  when Array
    hints << "  #{prefix}[]"
    if json.first.is_a?(Hash)
      json.first.keys.take(5).each do |key|
        hints << "  #{prefix}[].#{key}"
      end
    end
  end

  hints.take(10).join("\n")
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

  { content: [{ type: 'text', text: text }] }
end

def handle_vcr_prepare_rerecord(cassette_path, environment)
  environment ||= 'staging'
  result = VcrMcp::PreparationGuide.generate(cassette_path, environment: environment)

  if result[:error]
    return handle_error_result(result)
  end

  { content: [{ type: 'text', text: result[:guide] }] }
end

def handle_vcr_validate_cassette(cassette_path)
  result = VcrMcp::Validator.validate(cassette_path)

  if result[:error]
    return { isError: true, content: [{ type: 'text', text: result[:error] }] }
  end

  { content: [{ type: 'text', text: result[:report] }] }
end

def handle_vcr_patch_ssl(file_path, cassette_path)
  if file_path
    result = VcrMcp::SslPatcher.patch_file(file_path)
  elsif cassette_path
    result = VcrMcp::SslPatcher.patch_for_cassette(cassette_path)
  else
    return {
      isError: true,
      content: [{ type: 'text', text: 'Either file_path or cassette_path is required.' }]
    }
  end

  if result[:error]
    text = "Error: #{result[:error]}"
    text += "\nSuggestion: #{result[:suggestion]}" if result[:suggestion]
    return { isError: !result[:already_patched], content: [{ type: 'text', text: text }] }
  end

  if result[:results]
    # Multiple files patched (from cassette detection)
    text = "SSL patches applied for service: #{result[:service]}\n\n"
    text += "Patched files:\n"
    result[:patched_files].each { |f| text += "  ✓ #{f}\n" }
    text += "\nTo restore after recording:\n"
    text += "  Use vcr_unpatch_ssl tool\n"
    text += "  Or: git checkout #{result[:patched_files].join(' ')}\n"
  else
    text = "✓ #{result[:message]}\n\n"
    text += "Backup saved to: #{result[:backup]}\n\n"
    text += "To restore after recording:\n"
    text += "  Use vcr_unpatch_ssl tool\n"
    text += "  Or: git checkout #{result[:file]}\n"
  end

  { content: [{ type: 'text', text: text }] }
end

def handle_vcr_unpatch_ssl(file_path)
  if file_path
    result = VcrMcp::SslPatcher.unpatch_file(file_path)
    if result[:error]
      return { isError: true, content: [{ type: 'text', text: "Error: #{result[:error]}" }] }
    end

    text = "✓ #{result[:message]}"
  else
    result = VcrMcp::SslPatcher.unpatch_all
    if result[:unpatched].empty? && result[:errors].empty?
      text = "No patched files found."
    else
      text = "Unpatched files:\n"
      result[:unpatched].each { |f| text += "  ✓ #{f}\n" }
      if result[:errors].any?
        text += "\nErrors:\n"
        result[:errors].each { |e| text += "  ✗ #{e}\n" }
      end
    end
  end

  { content: [{ type: 'text', text: text }] }
end

def handle_vcr_list_ssl_patches
  result = VcrMcp::SslPatcher.list_patched_files

  if result[:count].zero?
    text = "No configuration files are currently patched for SSL bypass."
  else
    text = "Currently patched files (#{result[:count]}):\n\n"
    result[:files].each { |f| text += "  • #{f}\n" }
    text += "\nUse vcr_unpatch_ssl to restore these files."
  end

  { content: [{ type: 'text', text: text }] }
end

def handle_call_tool(name, arguments)
  case name
  when 'vcr_inspect_cassette'
    handle_vcr_inspect(arguments['cassette_path'], arguments['query'])
  when 'vcr_json_structure'
    handle_vcr_json_structure(
      arguments['cassette_path'],
      arguments['interaction_index'],
      arguments['max_depth'],
      arguments['include_request']
    )
  when 'vcr_find_specs'
    handle_vcr_find_specs(arguments['cassette_path'])
  when 'vcr_prepare_rerecord'
    handle_vcr_prepare_rerecord(arguments['cassette_path'], arguments['environment'])
  when 'vcr_validate_cassette'
    handle_vcr_validate_cassette(arguments['cassette_path'])
  when 'vcr_patch_ssl'
    handle_vcr_patch_ssl(arguments['file_path'], arguments['cassette_path'])
  when 'vcr_unpatch_ssl'
    handle_vcr_unpatch_ssl(arguments['file_path'])
  when 'vcr_list_ssl_patches'
    handle_vcr_list_ssl_patches
  else
    raise "Unknown tool: #{name}"
  end
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
