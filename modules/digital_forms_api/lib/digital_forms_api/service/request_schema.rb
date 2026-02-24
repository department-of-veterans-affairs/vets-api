# frozen_string_literal: true

require 'json'

require 'digital_forms_api/service/base'

module DigitalFormsApi
  module Service
    # Forms API submissions request schema retrieval service.
    class RequestSchema < Base
      # Time-to-live for cached request schema
      CACHE_TTL = 1.hour
      # Cache key for submissions request schema
      CACHE_KEY = 'digital_forms_api:request_schema:submissions'
      # Path to fetch OpenAPI document containing request schema; relative to API base endpoint
      OPENAPI_PATH = 'openapi.json'
      # Path to local backup schema file; relative to Rails root
      BACKUP_SCHEMA_PATH = 'modules/digital_forms_api/config/schemas/forms_api_submissions_request_schema.json'
      # JSON pointer path to request schema within OpenAPI document response body
      SCHEMA_POINTER = %w[paths /submissions post requestBody content application/json schema].freeze

      # GET and cache submissions request schema.
      #
      # @return [Hash] submissions request schema
      # @raise [ArgumentError] when schema cannot be loaded from any source
      def fetch
        Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
          fetch_from_openapi || fetch_from_backup
        end
      end

      private

      # @see DigitalFormsApi::Service::Base#endpoint
      def endpoint
        'openapi'
      end

      # Retrieve request schema from remote OpenAPI document.
      # @return [Hash, nil]
      def fetch_from_openapi
        response = perform(:get, OPENAPI_PATH, {}, {})
        parse_schema(response.body, source: 'forms_api_openapi')
      rescue => e
        track_schema_error("Failed to load submissions request schema from openapi.json: #{e.class}: #{e.message}")
        nil
      end

      # Retrieve request schema from local backup file.
      # @return [Hash]
      # @raise [ArgumentError] when backup schema is unavailable or invalid
      def fetch_from_backup
        path = Rails.root.join(backup_schema_path)
        body = JSON.parse(File.read(path))
        parse_schema(body, source: 'backup_schema_file')
      rescue Errno::ENOENT
        message = "Submissions request schema backup file not found: #{path}"
        track_schema_error(message)
        raise ArgumentError, message
      rescue JSON::ParserError => e
        message = "Submissions request schema backup file is not valid JSON: #{e.message}"
        track_schema_error(message)
        raise ArgumentError, message
      end

      # Parse and validate request schema payload.
      # @param body [Hash, Object]
      # @param source [String]
      # @return [Hash]
      # @raise [ArgumentError] when schema payload is not a Hash
      def parse_schema(body, source:)
        schema = extract_schema(body)
        return schema if schema.is_a?(Hash)

        message = "Submissions request schema from #{source} did not include a JSON schema " \
                  "(expected Hash, got #{schema.class})"
        track_schema_error(message)
        raise ArgumentError, message
      end

      # Extract submissions request schema from OpenAPI body or direct schema.
      # @param body [Hash, Object]
      # @return [Hash, Object]
      def extract_schema(body)
        return body if direct_schema?(body)

        body.dig(*SCHEMA_POINTER)
      end

      # @param body [Hash, Object]
      # @return [Boolean]
      def direct_schema?(body)
        body.is_a?(Hash) && body.key?('type') && body.key?('properties')
      end

      # @return [String]
      def backup_schema_path
        request_schema_settings = Settings.digital_forms_api.request_schema
        configured_path = request_schema_settings&.backup_path.to_s
        configured_path.presence || BACKUP_SCHEMA_PATH
      end

      # @param message [String]
      # @return [void]
      def track_schema_error(message)
        monitor.track_schema_payload_error('submissions_request', message, call_location: caller_locations.first)
      end
    end
  end
end
