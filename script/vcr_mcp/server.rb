#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'jmespath'
require_relative 'inspector'

$stdout.sync = true
$stderr.sync = true

def log(message)
  $stderr.puts "[VCR MCP] #{message}"
end

def handle_list_tools
  {
    tools: [
      {
        name: "vcr_inspect_cassette",
        description: "Inspect the contents of a VCR cassette file to see recorded HTTP interactions.",
        inputSchema: {
          type: "object",
          properties: {
            cassette_path: {
              type: "string",
              description: "The path or partial name of the cassette to inspect (e.g., 'mhv_account_type_service/premium')."
            },
            query: {
              type: "string",
              description: "Optional JMESPath query to filter the cassette content (e.g., 'interactions[].response.body.json.entry[].resource.id')."
            }
          },
          required: ["cassette_path"]
        }
      }
    ]
  }
end

def handle_call_tool(name, arguments)
  case name
  when "vcr_inspect_cassette"
    path = arguments["cassette_path"]
    query = arguments["query"]
    result = VcrMcp::Inspector.inspect(path, json: true)
    
    if result[:error]
      {
        isError: true,
        content: [
          {
            type: "text",
            text: result[:error] + (result[:matches] ? "\nMatches:\n" + result[:matches].join("\n") : "")
          }
        ]
      }
    elsif query
      begin
        # Convert to JSON and back to ensure string keys for JMESPath
        json_data = JSON.parse(result.to_json)
        query_result = JMESPath.search(query, json_data)
        
        {
          content: [
            {
              type: "text",
              text: JSON.pretty_generate(query_result)
            }
          ]
        }
      rescue => e
        {
          isError: true,
          content: [
            {
              type: "text",
              text: "JMESPath Error: #{e.message}"
            }
          ]
        }
      end
    else
      # Format the output nicely for the LLM
      text_output = "Cassette: #{path}\n"
      text_output += "Interactions: #{result[:interactions].length}\n\n"
      
      result[:interactions].each_with_index do |interaction, idx|
        text_output += "=" * 80 + "\n"
        text_output += "INTERACTION #{idx + 1} (Recorded: #{interaction[:recorded_at]})\n"
        text_output += "=" * 80 + "\n"
        
        req = interaction[:request]
        text_output += "REQUEST:\n"
        text_output += "  #{req[:method].upcase} #{req[:uri]}\n"
        text_output += "  Headers: #{JSON.generate(req[:headers])}\n"
        text_output += "  Body:\n"
        
        body = req[:body]
        body_str = if body.nil?
                     '<NO BODY>'
                   elsif body[:is_json]
                     JSON.pretty_generate(body[:json])
                   elsif body[:is_image]
                     "<IMAGE: #{body[:image_type]}>"
                   else
                     body[:raw]
                   end
        
        text_output += body_str.gsub(/^/, '    ') + "\n"
        
        res = interaction[:response]
        text_output += "-" * 80 + "\n"
        text_output += "RESPONSE:\n"
        text_output += "  Status: #{res[:status][:code]} #{res[:status][:message]}\n"
        text_output += "  Headers: #{JSON.generate(res[:headers])}\n"
        text_output += "  Body:\n"
        
        body = res[:body]
        body_str = if body.nil?
                     '<NO BODY>'
                   elsif body[:is_json]
                     JSON.pretty_generate(body[:json])
                   elsif body[:is_image]
                     "<IMAGE: #{body[:image_type]}>"
                   else
                     body[:raw]
                   end
                   
        text_output += body_str.gsub(/^/, '    ') + "\n\n"
      end

      {
        content: [
          {
            type: "text",
            text: text_output
          }
        ]
      }
    end
  else
    raise "Unknown tool: #{name}"
  end
end

log "Starting VCR MCP Server..."

while line = $stdin.gets
  begin
    request = JSON.parse(line)
    # log "Received: #{request['method']}"
    
    response = {
      jsonrpc: "2.0",
      id: request["id"]
    }

    if request["method"] == "initialize"
      response[:result] = {
        protocolVersion: "2024-11-05",
        capabilities: {
          tools: {}
        },
        serverInfo: {
          name: "vets-api-vcr",
          version: "1.0.0"
        }
      }
    elsif request["method"] == "notifications/initialized"
      # No response needed for notifications
      next
    elsif request["method"] == "tools/list"
      response[:result] = handle_list_tools
    elsif request["method"] == "tools/call"
      params = request["params"]
      response[:result] = handle_call_tool(params["name"], params["arguments"])
    else
      # Ignore other methods or return error
      # For now, just ignore to keep it simple
      next
    end

    puts JSON.generate(response)
    $stdout.flush
  rescue => e
    log "Error: #{e.message}"
    log e.backtrace.join("\n")
  end
end
