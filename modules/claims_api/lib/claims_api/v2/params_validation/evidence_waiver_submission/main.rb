# frozen_string_literal: true

require 'claims_api/v2/params_validation/evidence_waiver_submission/evidence_waiver_submission_info'
require 'claims_api/v2/params_validation/base'

module ClaimsApi
  module V2
    module ParamsValidation
      module EvidenceWaiverSubmission
        class Main < Base
          validate :validate_evidence_waiver_submission_info

          private

          def validate_evidence_waiver_submission_info
            evidence_waiver_submission_info_validator = EvidenceWaiverSubmissionInfo.new(data)

            return if evidence_waiver_submission_info_validator.valid?

            add_nested_errors_for(:evidence_waiver_submission_info, evidence_waiver_submission_info_validator)
          end
        end
      end
    end
  end
end
