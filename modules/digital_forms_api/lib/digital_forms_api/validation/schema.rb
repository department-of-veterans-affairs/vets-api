# frozen_string_literal: true

require 'digital_forms_api/monitor'
require 'digital_forms_api/service/base'
require 'json-schema'

# Containing module for validation functions related to the DigitalFormsApi Schemas
module DigitalFormsApi
  # containing module for validation functions related to JSON schemas fetched from the forms endpoint
  module Validation
    # containing module for schema validation functions
    module Schema
      module_function

      # validate a single property against the schema fetched from the forms endpoint
      # @param form_id [String] the form identifier (e.g., '21-686c')
      #
      # @param property [String|Symbol] the property to validate
      # @param value [Mixed] the value to validate
      #
      # @return [Mixed] valid value
      # @raise JSON::Schema::ValidationError
      def validate_schema_property(form_id, property, value)
        schema = fetch_form_schema(form_id)
        property_schema = schema.dig('properties', property.to_s)
        raise ArgumentError unless property_schema

        validate_against_schema(property_schema, value, form_id:)
        value
      end

      # assemble and validate the upload (POST) payload against the form schema
      # @param form_id [String] the form identifier (e.g., '21-686c')
      #
      # @param file_name [String] name for the content being uploaded, must be unique for the destination folder
      # @param provider_data [Hash] metadata to be applied to the uploaded content; upload requires certain fields
      #
      # @return [Hash] valid upload payload
      # @raise JSON::Schema::ValidationError
      def validate_upload_payload(form_id, file_name, provider_data)
        payload = {
          contentName: file_name,
          providerData: provider_data
        }

        validate_against_schema(fetch_form_schema(form_id), payload, form_id:)

        payload
      end

      # validate the provider data to be applied to content using the form schema
      # @param form_id [String] the form identifier (e.g., '21-686c')
      #
      # @param provider_data [Hash] metadata to be applied to the uploaded content
      #
      # @return [Hash] valid upload payload
      # @raise JSON::Schema::ValidationError
      def validate_provider_data(form_id, provider_data)
        schema = fetch_form_schema(form_id)
        provider_schema = schema.dig('properties', 'providerData')
        raise ArgumentError unless provider_schema

        validate_against_schema(provider_schema, provider_data, form_id:)

        provider_data
      end

      # assemble and validate the file:search (POST) payload against the form schema
      # @param form_id [String] the form identifier (e.g., '21-686c')
      #
      # @param results_per_page [Integer] number of results per page; default = 10
      # @param page [Integer] page to begin returning results; default = 1
      # @param filters [Hash] filters to be applied to the search
      # @param sort [Array<Hash>] sort criteria to apply to the results
      #
      # @return [Hash] valid file:search payload
      # @raise JSON::Schema::ValidationError
      def validate_search_file_request(form_id, results_per_page: 10, page: 1, filters: {}, sort: [])
        request = {
          pageRequest: {
            resultsPerPage: normalize_integer(results_per_page, 10),
            page: normalize_integer(page, 1)
          },
          filters: (filters || {}).compact,
          sort: (sort || []).compact
        }

        validate_against_schema(fetch_form_schema(form_id), request, form_id:)

        request
      end

      # Utility function to fetch the JSON schema for a given form_id from the API
      # @param form_id [String] the form identifier (e.g., '21-686c')
      # @return [Hash] the JSON schema for the specified form_id
      # @raise JSON::Schema::ValidationError if the API response does not include a valid JSON schema
      # @note This function assumes that the API response for the schema endpoint includes a JSON schema
      # either directly in the body or nested within a 'data' key,
      # which should be adjusted if the API response structure changes
      #
      # @example
      #   # If the API response body is the schema itself
      #   response_body = {
      #     "type" => "object",
      #     "properties" => {
      #       "contentName" => { "type" => "string" },
      #       "providerData" => { "type" => "object" }
      #     },
      #     "required" => ["contentName", "providerData"]
      #   }
      #   fetch_form_schema('21-686c') # => returns the response body as the schema
      #   # If the API response body has the schema nested within a 'data' key
      #   response_body = {
      #     "data" => {
      #       "schema" => {
      #         "type" => "object",
      #         "properties" => {
      #           "contentName" => { "type" => "string" },
      #           "providerData" => { "type" => "object" }
      #         },
      #         "required" => ["contentName", "providerData"]
      #       }
      #     }
      #   }
      #   fetch_form_schema('21-686c') # => returns the nested schema at response_body['data']['schema']
      def fetch_form_schema(form_id)
        response = DigitalFormsApi::Service::Base.new.perform(:get, "schemas/#{form_id}", {}, {})
        schema = extract_schema_from_response(response.body)
        unless schema.is_a?(Hash)
          fallback_schema = JSON::Schema.new({}, 'inline://schema')
          message = "Schema response for form_id '#{form_id}' did not include a JSON schema " \
                    "(expected Hash, got #{schema.class})"
          track_schema_error(form_id, message)
          raise JSON::Schema::ValidationError.new(message, [], nil, fallback_schema)
        end

        schema
      end

      # Utility function to validate a value against a given JSON schema
      # @param schema [Hash] the JSON schema to validate against
      # @param value [Mixed] the value to be validated against the schema
      # @return [Mixed] the validated value if it conforms to the schema
      # @raise [JSON::Schema::ValidationError] if the value does not conform to the schema
      # or if there is an error in the schema itself
      # @example
      #   schema = {
      #     "type" => "object",
      #     "properties" => {
      #       "contentName" => { "type" => "string" },
      #       "providerData" => { "type" => "object" }
      #     },
      #     "required" => ["contentName", "providerData"]
      #   }
      #   value = { contentName: 'test.pdf', providerData: { key: 'value' } }
      #   validate_against_schema(schema, value) # => returns the value if it is valid according to the schema
      #   invalid_value = { contentName: 'test.pdf' }
      #   validate_against_schema(schema, invalid_value) # => raises JSON::Schema::ValidationError
      #   because providerData is required
      def validate_against_schema(schema, value, form_id: nil)
        JSON::Validator.validate!(schema, value)
        value
      rescue JSON::Schema::SchemaParseError => e
        track_schema_error(form_id, e.message)
        fallback_schema = JSON::Schema.new({}, 'inline://schema')
        raise JSON::Schema::ValidationError.new(e.message, [], nil, fallback_schema)
      end

      # Utility function to normalize pagination parameters,
      # ensuring they are integers and applying defaults if necessary
      # @param value [Mixed] the value to be normalized
      # @param default [Integer] the default value to use if the provided value is nil or not present
      # @return [Integer] the normalized integer value for pagination parameters
      # @example
      #   normalize_integer('5', 10) # => returns 5 as an integer
      #   normalize_integer(nil, 10) # => returns 10 as the default value
      #   normalize_integer('invalid', 10) # => returns 10 as the default value
      #   since 'invalid' cannot be converted to an integer
      def normalize_integer(value, default)
        value = value.presence if value.respond_to?(:presence)
        return default if value.nil?
        return value if value.is_a?(Integer)

        Integer(value, 10)
      rescue ArgumentError, TypeError
        default
      end

      # Utility function to track schema-related errors in the monitor
      # @param form_id [String] the form identifier associated with the schema error, if available
      # @param message [String] the error message to be logged in the monitor
      # @return [void]
      def track_schema_error(form_id, message)
        reason = form_id ? "form_id=#{form_id} #{message}" : message
        monitor.track_api_request(:get, 'schemas', 500, reason, call_location: caller_locations.first)
      end

      # Utility function to access the monitor instance for logging schema-related errors
      # @return [DigitalFormsApi::Monitor::Service] the monitor instance used for logging
      def monitor
        Thread.current[:digital_forms_api_schema_monitor] ||= DigitalFormsApi::Monitor::Service.new
      end

      # Utility function to extract the JSON schema from the response body
      # Which may be directly the body or nested within a 'data' key, depending on the endpoint's response structure
      # @param body [Hash] the response body from which to extract the schema
      # @return [Hash] the extracted JSON schema
      # @raise [JSON::Schema::ValidationError] if the schema cannot be found in the response body
      # @note This function assumes that the schema is either the entire body
      # or located at body['data']['schema'], which should be adjusted if the API response structure changes
      #
      # @example
      #   # If the response body is the schema itself
      #   body = {
      #     "type" => "object",
      #     "properties" => {
      #       "contentName" => { "type" => "string" },
      #       "providerData" => { "type" => "object" }
      #     },
      #     "required" => ["contentName", "providerData"]
      #   }
      #   extract_schema_from_response(body) # => returns the body as the schema
      #   #   # If the response body has the schema nested within a 'data' key
      #   body = {
      #     "data" => {
      #       "schema" => {
      #         "type" => "object",
      #         "properties" => {
      #           "contentName" => { "type" => "string" },
      #           "providerData" => { "type" => "object" }
      #           },
      #             "required" => ["contentName", "providerData"]
      #       }
      #     }
      #   }
      #   extract_schema_from_response(body) # => returns the nested schema at body['data']['schema']
      def extract_schema_from_response(body)
        return body['schema'] if body.is_a?(Hash) && body.key?('schema')
        return body.dig('data', 'schema') if body.is_a?(Hash) && body.key?('data')

        body
      end
    end
  end
end
