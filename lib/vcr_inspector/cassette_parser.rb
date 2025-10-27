# frozen_string_literal: true

module VcrInspector
  class CassetteParser
    def self.parse(file_path)
      yaml_content = YAML.load_file(file_path)
      
      {
        interactions: parse_interactions(yaml_content['http_interactions']),
        raw: yaml_content
      }
    rescue StandardError => e
      {
        error: "Failed to parse cassette: #{e.message}",
        interactions: []
      }
    end

    def self.parse_interactions(interactions)
      return [] unless interactions

      interactions.map do |interaction|
        {
          request: parse_request(interaction['request']),
          response: parse_response(interaction['response']),
          recorded_at: interaction['recorded_at']
        }
      end
    end

    def self.parse_request(request)
      {
        method: request['method'],
        uri: request['uri'],
        headers: request['headers'] || {},
        body: parse_body(request['body'])
      }
    end

    def self.parse_response(response)
      {
        status: {
          code: response['status']['code'],
          message: response['status']['message']
        },
        headers: response['headers'] || {},
        body: parse_body(response['body'])
      }
    end

    def self.parse_body(body)
      return nil unless body
      
      string = body['string'] || ''
      encoding = body['encoding']
      
      # Try to decode base64 if encoded
      if encoding == 'ASCII-8BIT' || encoding == 'US-ASCII'
        begin
          decoded = Base64.decode64(string) if string.match?(/^[A-Za-z0-9+\/]+=*$/)
          string = decoded if decoded && decoded.valid_encoding?
        rescue StandardError
          # Keep original if decode fails
        end
      end

      # Try to parse as JSON for better display
      begin
        parsed_json = JSON.parse(string)
        return { json: parsed_json, raw: string, is_json: true }
      rescue JSON::ParserError
        # Not JSON, return as is
      end

      { raw: string, is_json: false }
    end
  end
end
