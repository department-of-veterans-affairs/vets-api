# frozen_string_literal: true

require 'json'

require 'digital_forms_api/service/base'

module DigitalFormsApi
  module Service
    # Forms API OpenAPI retrieval service.
    class RequestSchema < Base
      # Time-to-live for cached OpenAPI schema
      CACHE_TTL = 1.hour
      # Cache key for OpenAPI schema document
      CACHE_KEY = 'digital_forms_api:request_schema:openapi'
      # Path to fetch OpenAPI document from API root
      OPENAPI_PATH = '/openapi.json'

      # GET and cache Forms API OpenAPI schema.
      #
      # @return [Hash] OpenAPI schema document
      # @raise [ArgumentError] when schema document cannot be loaded from any source
      def fetch
        Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
          fetch_from_openapi || fetch_from_backup
        end
      end

      # Extract and resolve the submissions request schema from OpenAPI.
      #
      # @return [Hash] resolved submissions request schema
      # @raise [ArgumentError] when request schema cannot be extracted
      def fetch_submission_request_schema
        openapi = fetch
        request_body = extract_submissions_request_body(openapi)
        schema = extract_content_schema(request_body, openapi)

        return schema if schema.is_a?(Hash)

        message = 'Submissions request schema could not be extracted from OpenAPI document'
        track_schema_error(message)
        raise ArgumentError, message
      end

      private

      # @see DigitalFormsApi::Service::Base#endpoint
      def endpoint
        'openapi'
      end

      # Retrieve OpenAPI document from remote API.
      # @return [Hash, nil]
      def fetch_from_openapi
        response = perform(:get, OPENAPI_PATH, {}, {})
        parse_openapi(response.body, source: 'forms_api_openapi')
      rescue => e
        track_schema_error("Failed to load submissions request schema from openapi.json: #{e.class}: #{e.message}")
        nil
      end

      # Retrieve OpenAPI document from local backup file.
      # @return [Hash]
      # @raise [ArgumentError] when backup OpenAPI is unavailable or invalid
      def fetch_from_backup
        path = Rails.root.join(backup_schema_path)
        body = JSON.parse(File.read(path))
        parse_openapi(body, source: 'backup_schema_file')
      rescue Errno::ENOENT
        message = "Forms API OpenAPI backup file not found: #{path}"
        track_schema_error(message)
        raise ArgumentError, message
      rescue JSON::ParserError => e
        message = "Forms API OpenAPI backup file is not valid JSON: #{e.message}"
        track_schema_error(message)
        raise ArgumentError, message
      end

      # Parse and validate OpenAPI payload.
      # @param body [Hash, Object]
      # @param source [String]
      # @return [Hash]
      # @raise [ArgumentError] when OpenAPI payload is not a Hash
      def parse_openapi(body, source:)
        return body if body.is_a?(Hash)

        message = "Forms API OpenAPI payload from #{source} did not include a JSON object " \
                  "(expected Hash, got #{body.class})"
        track_schema_error(message)
        raise ArgumentError, message
      end

      # Extract requestBody object for the POST submissions operation.
      # @param openapi [Hash]
      # @return [Hash]
      # @raise [ArgumentError] when requestBody cannot be found
      def extract_submissions_request_body(openapi)
        path_item = find_submissions_path_item(openapi)
        request_body = path_item&.dig('post', 'requestBody')
        request_body = resolve_reference(request_body, openapi)

        return request_body if request_body.is_a?(Hash)

        message = 'Submissions POST requestBody not found in OpenAPI document'
        track_schema_error(message)
        raise ArgumentError, message
      end

      # Extract and resolve application/json schema from a requestBody object.
      # @param request_body [Hash]
      # @param openapi [Hash]
      # @return [Hash, nil]
      def extract_content_schema(request_body, openapi)
        content = request_body['content']
        return unless content.is_a?(Hash)

        schema = content.dig('application/json', 'schema') || content.dig('application/*+json', 'schema')
        resolve_reference(schema, openapi)
      end

      # Locate the submissions path item from OpenAPI paths.
      # @param openapi [Hash]
      # @return [Hash, nil]
      def find_submissions_path_item(openapi)
        paths = openapi['paths']
        return unless paths.is_a?(Hash)

        paths['/submissions'] || paths.values.find do |path_item|
          path_item.is_a?(Hash) && path_item['post'].is_a?(Hash)
        end
      end

      # Resolve JSON Reference values recursively.
      # @param node [Hash, Array, Object]
      # @param openapi [Hash]
      # @return [Hash, Array, Object]
      def resolve_reference(node, openapi)
        case node
        when Hash
          if node.key?('$ref')
            referenced = resolve_pointer(openapi, node['$ref'])
            return resolve_reference(referenced, openapi)
          end

          node.transform_values { |value| resolve_reference(value, openapi) }
        when Array
          node.map { |value| resolve_reference(value, openapi) }
        else
          node
        end
      end

      # Resolve a JSON pointer-style reference against the OpenAPI hash.
      # @param openapi [Hash]
      # @param ref [String]
      # @return [Object, nil]
      def resolve_pointer(openapi, ref)
        return unless ref.is_a?(String) && ref.start_with?('#/')

        tokens = ref.delete_prefix('#/').split('/').map do |token|
          token.gsub('~1', '/').gsub('~0', '~')
        end

        tokens.reduce(openapi) do |memo, token|
          memo.is_a?(Hash) ? memo[token] : nil
        end
      end

      # @return [String]
      def backup_schema_path
        request_schema_setting = Settings.digital_forms_api.request_schema
        configured_path = extract_backup_schema_path(request_schema_setting)
        return configured_path if configured_path.present?

        message = 'Settings.digital_forms_api.request_schema must be configured with the backup OpenAPI path'
        track_schema_error(message)
        raise ArgumentError, message
      end

      # Extract backup schema path from current or legacy setting shapes.
      # @param setting [Object]
      # @return [String]
      def extract_backup_schema_path(setting)
        case setting
        when String
          setting
        when Hash
          setting[:backup_path].to_s.presence || setting['backup_path'].to_s
        else
          if setting.respond_to?(:backup_path)
            setting.backup_path.to_s
          elsif setting.respond_to?(:to_h)
            setting_hash = setting.to_h
            setting_hash[:backup_path].to_s.presence || setting_hash['backup_path'].to_s
          else
            setting.to_s
          end
        end
      end

      # @param message [String]
      # @return [void]
      def track_schema_error(message)
        monitor.track_schema_payload_error('submissions_request', message, call_location: caller_locations.first)
      end
    end
  end
end
