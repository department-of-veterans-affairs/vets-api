# frozen_string_literal: true

require 'claims_api/claim_logger'

module ClaimsApi
  module V2
    class DisabilityCompensationClaimService
      def get_pending_claim(claim_id)
        ClaimsApi::V2::AutoEstablishedClaim.find(claim_id)
      end

      def set_claim_as_established(claim_id)
        claim = get_claim(claim_id)

        claim.status = ClaimsApi::V2::AutoEstablishedClaim::ESTABLISHED
        claim.save
      end

      def set_errored_state(error, claim_id)
        claim = get_claim(claim_id)
        get_error_status_code(error)
        error_message = get_error_message(error)

        claim.status = ClaimsApi::V2::AutoEstablishedClaim::ERRORED
        claim.evss_response = [{ 'key' => error_key, 'severity' => 'FATAL', 'text' => error_message }]
        claim.save
      end

      def get_error_status_code(error)
        if error.respond_to? :status_code
          error.status_code
        else
          "No status code for error: #{error}"
        end
      end

      def get_error_message(error)
        if error.respond_to? :original_body
          error.original_body
        else
          error.message
        end
      end

      def log_job_progress(tag, claim_id, detail)
        ClaimsApi::Logger.log(tag,
                              claim_id:,
                              detail:)
      end
    end
  end
end
