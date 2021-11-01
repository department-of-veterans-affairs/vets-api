# frozen_string_literal: true

require 'claims_api/v2/params_validation/base'
require 'claims_api/v2/params_validation/power_of_attorney/poa_submission_validator'

module ClaimsApi
  module V2
    module ParamsValidation
      module PowerOfAttorney
        class PoaSubmission < Base
          validates_with PoaSubmissionValidator
        end
      end
    end
  end
end
