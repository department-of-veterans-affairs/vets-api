# frozen_string_literal: true

require 'claims_api/v2/params_validation/power_of_attorney/poa_submission'
require 'claims_api/v2/params_validation/base'

module ClaimsApi
  module V2
    module ParamsValidation
      module PowerOfAttorney
        class Main < Base
          validate :validate_poa_submission

          private

          def validate_poa_submission
            poa_submission_validator = PoaSubmission.new(data)

            return if poa_submission_validator.valid?

            add_nested_errors_for(:poa_submission, poa_submission_validator)
          end
        end
      end
    end
  end
end
