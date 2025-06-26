# frozen_string_literal: true

require_relative 'validation/field'

module ClaimsEvidenceApi
  module Validation
    def validate_field(value, type:, **validations)
      BaseField.new(type:, **validations).validate(value)
    end

    # end Validations
  end

  # end ClaimsEvidenceApi
end
