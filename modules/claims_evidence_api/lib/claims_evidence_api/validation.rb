# frozen_string_literal: true

require_relative 'validation/field'

module ClaimsEvidenceApi
  # base validation module
  module Validation
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

    # end Validations
  end

  # end ClaimsEvidenceApi
end
