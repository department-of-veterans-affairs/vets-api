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
      
      # Handle binary data (already decoded by YAML's !binary tag)
      if encoding == 'ASCII-8BIT' && !string.empty?
        # Check if it's already binary (from !binary YAML tag)
        image_type = detect_image_type(string)
        if image_type
          # Re-encode to base64 for data URI
          base64_string = Base64.strict_encode64(string)
          return { 
            raw: base64_string, 
            is_json: false, 
            is_image: true, 
            image_type: image_type,
            data_uri: "data:image/#{image_type};base64,#{base64_string}"
          }
        end
      end
      
      # Handle base64 encoded text (US-ASCII encoding)
      if encoding == 'US-ASCII' && string.match?(/^[A-Za-z0-9+\/]+=*$/)
        begin
          decoded = Base64.decode64(string)
          image_type = detect_image_type(decoded)
          if image_type
            return { 
              raw: string, 
              is_json: false, 
              is_image: true, 
              image_type: image_type,
              data_uri: "data:image/#{image_type};base64,#{string}"
            }
          end
          # Not an image, but might be decodable text
          string = decoded if decoded.valid_encoding?
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

    def self.detect_image_type(binary_data)
      return nil if binary_data.nil? || binary_data.empty?
      
      # Check magic bytes for common image formats
      return 'gif' if binary_data[0..5] == "GIF89a" || binary_data[0..5] == "GIF87a"
      return 'png' if binary_data[0..3] == "\x89PNG"
      return 'jpeg' if binary_data[0..2] == "\xFF\xD8\xFF"
      return 'webp' if binary_data.length > 12 && binary_data[8..11] == 'WEBP'
      return 'bmp' if binary_data[0..1] == 'BM'
      
      nil
    end
  end
end
