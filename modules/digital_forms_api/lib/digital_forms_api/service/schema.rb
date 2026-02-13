# frozen_string_literal: true

require 'digital_forms_api/service/base'

module DigitalFormsApi
  module Service
    # Forms API schema retrieval service.
    class Schema < Base
      # Default cache ttl for fetched schemas.
      # @return [ActiveSupport::Duration]
      CACHE_TTL = 1.hour

      # GET retrieve a form schema from Forms API
      #
      # @param form_id [String] the form identifier, eg. '21-686c'
      # @return [Hash] parsed json schema
      def fetch(form_id)
        Rails.cache.fetch(cache_key(form_id), expires_in: CACHE_TTL) do
          response = perform(:get, form_schema_path(form_id), {}, {})
          parse_schema(response.body, form_id)
        end
      end

      private

      # @see DigitalFormsApi::Service::Base#endpoint
      def endpoint
        'schemas'
      end

      # Build schema endpoint path for the provided form.
      # @param form_id [String]
      # @return [String]
      def form_schema_path(form_id)
        "schemas/#{form_id}"
      end

      # Build cache key for a form schema.
      # @param form_id [String]
      # @return [String]
      def cache_key(form_id)
        "digital_forms_api:schema:#{form_id}"
      end

      # Parse and validate schema payload from API response body.
      # @param body [Hash, Object]
      # @param form_id [String]
      # @return [Hash]
      # @raise [ArgumentError] when schema payload is not a Hash
      def parse_schema(body, form_id)
        schema = extract_schema(body)
        return schema if schema.is_a?(Hash)

        message = "Schema response for form_id '#{form_id}' did not include a JSON schema " \
                  "(expected Hash, got #{schema.class})"
        monitor.track_api_request(:get, endpoint, 500, message, call_location: caller_locations.first)
        raise ArgumentError, message
      end

      # Extract schema payload from top-level or nested response structures.
      # @param body [Hash, Object]
      # @return [Hash, Object]
      def extract_schema(body)
        return body['schema'] if body.is_a?(Hash) && body.key?('schema')
        return body.dig('data', 'schema') if body.is_a?(Hash) && body.key?('data')

        body
      end
    end
  end
end
