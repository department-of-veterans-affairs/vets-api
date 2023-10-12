# frozen_string_literal: true

require 'claims_api/claim_logger'

module ClaimsApi
  module V2
    class DisabilityCompensationClaimProcessor

      protected

      def get_claim(claim_id)
        ClaimsApi::V2::AutoEstablishedClaim.find(claim_id)
      end

      def log_job_progress(tag, claim_id, detail)
        ClaimsApi::Logger.log(tag, 
            claim_id: claim_id, 
            detail: detail)
      end
    end
  end
end