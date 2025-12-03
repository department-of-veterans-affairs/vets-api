# frozen_string_literal: true

require 'yaml'
require 'json'
require 'base64'

module VcrMcp
  class CassetteParser
    def self.parse(file_path)
      yaml_content = YAML.safe_load_file(file_path, permitted_classes: [], permitted_symbols: [], aliases: true)

      {
        interactions: parse_interactions(yaml_content['http_interactions']),
        raw: yaml_content
      }
    rescue => e
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

      # Handle binary data
      image_result = check_for_binary_image(string, encoding)
      return image_result if image_result

      # Handle base64 encoded content
      image_result = check_for_base64_image(string, encoding)
      return image_result if image_result

      # Try to parse as JSON
      parse_as_json(string)
    end

    def self.check_for_binary_image(string, encoding)
      return nil unless encoding == 'ASCII-8BIT' && !string.empty?

      image_type = detect_image_type(string)
      return nil unless image_type

      base64_string = Base64.strict_encode64(string)
      {
        raw: base64_string,
        is_json: false,
        is_image: true,
        image_type:,
        data_uri: "data:image/#{image_type};base64,#{base64_string}"
      }
    end

    def self.check_for_base64_image(string, encoding)
      return nil unless encoding == 'US-ASCII' && string.match?(%r{^[A-Za-z0-9+/]+=*$})

      decoded = Base64.decode64(string)
      image_type = detect_image_type(decoded)
      return update_string_if_text(string, decoded) unless image_type

      {
        raw: string,
        is_json: false,
        is_image: true,
        image_type:,
        data_uri: "data:image/#{image_type};base64,#{string}"
      }
    rescue ArgumentError
      nil
    end

    def self.update_string_if_text(original, decoded)
      return nil unless decoded.valid_encoding?

      # Returning nil causes the caller to continue processing
      original.replace(decoded)
      nil
    end

    def self.parse_as_json(string)
      parsed_json = JSON.parse(string)
      { json: parsed_json, raw: string, is_json: true }
    rescue JSON::ParserError
      { raw: string, is_json: false }
    end

    # rubocop:disable Rails/Blank - standalone script without ActiveSupport
    def self.detect_image_type(binary_data)
      return nil if binary_data.nil? || binary_data.empty?

      # Check magic bytes for common image formats
      return 'gif' if %w[GIF89a GIF87a].include?(binary_data[0..5])
      return 'png' if binary_data[0..3] == "\x89PNG"
      return 'jpeg' if binary_data[0..2] == "\xFF\xD8\xFF"
      return 'webp' if binary_data.length > 12 && binary_data[8..11] == 'WEBP'
      return 'bmp' if binary_data[0..1] == 'BM'

      nil
    end
  end
  # rubocop:enable Rails/Blank
end
