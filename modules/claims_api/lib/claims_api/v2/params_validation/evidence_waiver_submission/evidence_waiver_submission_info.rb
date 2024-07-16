# frozen_string_literal: true

require 'claims_api/v2/params_validation/base'
require 'claims_api/v2/params_validation/evidence_waiver_submission/evidence_waiver_submission_validator'

module ClaimsApi
  module V2
    module ParamsValidation
      module EvidenceWaiverSubmission
        class EvidenceWaiverSubmissionInfo < Base
          validates_with EvidenceWaiverSubmissionValidator
        end
      end
    end
  end
end
