#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'jmespath'
require_relative 'inspector'

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

def handle_list_tools
  { tools: [vcr_inspect_tool_schema] }
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

def handle_vcr_inspect(path, query)
  result = VcrMcp::Inspector.inspect(path, json: true)

  return handle_error_result(result) if result[:error]
  return handle_query_result(result, query) if query

  format_cassette_output(path, result)
end

def handle_call_tool(name, arguments)
  case name
  when 'vcr_inspect_cassette'
    handle_vcr_inspect(arguments['cassette_path'], arguments['query'])
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
