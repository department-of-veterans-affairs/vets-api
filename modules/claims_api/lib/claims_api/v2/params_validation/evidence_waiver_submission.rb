# frozen_string_literal: true

require 'claims_api/v2/params_validation/evidence_waiver_submission/main'

module ClaimsApi
  module V2
    module ParamsValidation
      module EvidenceWaiverSubmission
        def self.validator(params)
          EvidenceWaiverSubmission::Main.new(params)
        end
      end
    end
  end
end
