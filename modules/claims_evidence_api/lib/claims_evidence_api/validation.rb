# frozen_string_literal: true

require 'claims_evidence_api/validation/field'
require 'claims_evidence_api/x_folder_uri'

module ClaimsEvidenceApi
  # Validations to be used with ClaimsEvidence API requests
  module Validation
    # ClaimsEvidenceApi::XFolderUri#validate
    def validate_folder_identifier(folder_identifier)
      ClaimsEvidenceApi::XFolderUri.validate(folder_identifier)
    end

    # validate a field value against a set of validations
    # @see ClaimsEvidenceApi::Validation::BaseField
    #
    # @param value [Mixed] the value to be validated
    # @param type [String|Symbol] the field type being validated
    # @param validations [Hash] named key:value pairs to be used to validate the value
    # => `key` must be a defined function on BaseField
    # => `value` will be the appropriate check applied to the value param
    #
    # @example validate_field(23, type: :integer, min: 1, max: 50)
    #
    # @raise [ArgumentError] if the field value is not valid
    #
    # @return [Mixed] the value if valid
    def validate_field(value, type:, **validations)
      ClaimsEvidenceApi::Validation::BaseField.new(type:, **validations).validate(value)
    end

    # end Validation
  end

  # end ClaimsEvidenceApi
end
