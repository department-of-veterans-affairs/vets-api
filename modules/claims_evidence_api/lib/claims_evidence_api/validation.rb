# frozen_string_literal: true

# require 'claims_evidence_api/x_folder_uri'

module ClaimsEvidenceApi
  # Validations to be used with ClaimsEvidence API requests
  module Validation
    module_function

    # ClaimsEvidenceApi::XFolderUri#validate
    def validate_folder_identifier(folder_identifier)
      # ClaimsEvidenceApi::XFolderUri.validate(folder_identifier)
    end

    def validate_upload_payload(content_name, provider_data)
      payload = {
        contentName: content_name,
        providerData: provider_data
      }

      JSON::Validator.validate!("#{__dir__}/schema/uploadPayload.json", payload)

      payload
    end

    # end Validation
  end

  # end ClaimsEvidenceApi
end
