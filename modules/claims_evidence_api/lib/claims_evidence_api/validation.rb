# frozen_string_literal: true

require 'claims_evidence_api/json_schema'
require 'claims_evidence_api/validation/field'
require 'claims_evidence_api/folder_identifier'

module ClaimsEvidenceApi
  module Validation
    module_function

    # @see ClaimsEvidenceApi::FolderIdentifier#validate
    def validate_folder_identifier(folder_identifier)
      ClaimsEvidenceApi::FolderIdentifier.validate(folder_identifier)
    end

    # @see ClaimsEvidenceApi::Validation::BaseField
    def validate_field_value(value, field_type:, **validations)
      ClaimsEvidenceApi::Validation::BaseField.new(type: field_type, **validations).validate(value)
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

    # end Validation
  end

  # end ClaimsEvidenceApi
end
