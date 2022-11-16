# frozen_string_literal: true

module ClaimsApi
  class EvidenceWaiverSubmissionUploader < ClaimsApi::BaseUploader
    def location
      'evidence_waiver_submission'
    end
  end
end
