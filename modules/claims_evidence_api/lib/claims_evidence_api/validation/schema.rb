# frozen_string_literal: true

module ClaimsEvidenceApi
  module Validation
    # containing module for schema validation functions
    module Schema
      module_function

      # validate a single property against the schema
      # @see ClaimsEvidenceApi::JsonSchema::PROPERTIES
      #
      # @param property [String|Symbol] the property to validate
      # @param value [Mixed] the value to validate
      #
      # @return [Mixed] valid value
      # @raise JSON::Schema::ValidationError
      def validate_schema_property(property, value)
        prop = property.to_sym
        raise ArgumentError unless ClaimsEvidenceApi::JsonSchema::PROPERTIES.key?(prop)

        JSON::Validator.validate!(ClaimsEvidenceApi::JsonSchema::PROPERTIES[prop], value)
        value
      end

      # assemble and validate the upload (POST) payload
      # @see modules/claims_evidence_api/lib/claims_evidence_api/schema/uploadPayload.json
      #
      # @param file_name [String] name for the content being uploaded, must be unique for the destination folder
      # @param provider_data [Hash] metadata to be applied to the uploaded content; upload requires certain fields
      #
      # @return [Hash] valid upload payload
      # @raise JSON::Schema::ValidationError
      def validate_upload_payload(file_name, provider_data)
        payload = {
          contentName: file_name,
          providerData: provider_data
        }

        JSON::Validator.validate!(ClaimsEvidenceApi::JsonSchema::UPLOAD_PAYLOAD, payload)

        payload
      end

      # validate the provider data to be applied to content
      #
      # @param provider_data [Hash] metadata to be applied to the uploaded content
      #
      # @return [Hash] valid upload payload
      # @raise JSON::Schema::ValidationError
      def validate_provider_data(provider_data)
        JSON::Validator.validate!(ClaimsEvidenceApi::JsonSchema::PROVIDER_DATA, provider_data)

        provider_data
      end

      # assemble and validate the file:search (POST) payload
      # @see ClaimsEvidenceApi::Validation::SearchFileRequest
      # @see modules/claims_evidence_api/lib/claims_evidence_api/schema/searchFileRequest.json
      #
      # @param results_per_page [Integer] number of results per page; default = 10
      # @param page [Integer] page to begin returning results; default = 1
      # @param filters [Hash] filters to be applied to the search
      # @param sort [Hash] sort to apply to the results
      #
      # @return [Hash] valid file:search payload
      # @raise JSON::Schema::ValidationError
      def validate_search_file_request(results_per_page: 10, page: 1, filters: {}, sort: [])
        request = {
          pageRequest: {
            resultsPerPage: results_per_page.to_i,
            page: page.to_i
          },
          filters: (filters || {}).compact,
          sort: (sort || []).compact
        }

        JSON::Validator.validate!(ClaimsEvidenceApi::JsonSchema::SEARCH_FILE_REQUEST, request)

        request
      end
    end
  end
end
