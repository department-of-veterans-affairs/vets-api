# frozen_string_literal: true

require 'claims_api/claim_logger'

module ClaimsApi
  module V2
    class DisabilityCompensationClaimService

      protected

      def set_claim_as_established(claim_id)
        claim = get_claim(claim_id)

        claim.status = ClaimsApi::V2::AutoEstablishedClaim::ESTABLISHED
        claim.save
      end

      def set_errored_state(error, claim_id)
        claim = get_claim(claim_id)

        claim.status = ClaimsApi::V2::AutoEstablishedClaim::ERRORED
        claim.evss_response = [{ 'key' => error&.status_code, 'severity' => 'FATAL', 'text' => error&.original_body }]
        claim.save
      end

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