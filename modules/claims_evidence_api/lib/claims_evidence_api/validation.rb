# frozen_string_literal: true

require 'claims_evidence_api/json_schema'
require 'claims_evidence_api/validation/field'
require 'claims_evidence_api/validation/schema'
require 'claims_evidence_api/validation/search_file_request'
require 'claims_evidence_api/folder_identifier'

module ClaimsEvidenceApi
  module Validation
    include ClaimsEvidenceApi::Validation::Schema

    module_function

    # @see ClaimsEvidenceApi::FolderIdentifier#validate
    def validate_folder_identifier(folder_identifier)
      ClaimsEvidenceApi::FolderIdentifier.validate(folder_identifier)
    end

    # @see ClaimsEvidenceApi::Validation::BaseField
    def validate_field_value(value, field_type:, **validations)
      ClaimsEvidenceApi::Validation::BaseField.new(type: field_type, **validations).validate(value)
    end

    # end Validation
  end

  # end ClaimsEvidenceApi
end
