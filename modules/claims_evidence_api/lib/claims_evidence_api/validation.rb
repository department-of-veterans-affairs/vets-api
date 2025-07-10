# frozen_string_literal: true

require 'claims_evidence_api/json_schema'
require 'claims_evidence_api/validation/field'
require 'claims_evidence_api/x_folder_uri'

module ClaimsEvidenceApi
  # Validations to be used with ClaimsEvidence API requests
  module Validation
    module_function

    # @see ClaimsEvidenceApi::XFolderUri#validate
    def validate_folder_identifier(folder_identifier)
      ClaimsEvidenceApi::XFolderUri.validate(folder_identifier)
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

    # end Validation
  end

  # end ClaimsEvidenceApi
end
