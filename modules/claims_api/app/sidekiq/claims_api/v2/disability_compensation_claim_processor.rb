# frozen_string_literal: true

require 'claims_api/claim_logger'

module ClaimsApi
  module V2
    class DisabilityCompensationClaimProcessor

      def process_claim(claim_id)
        log_job_progress('dis_comp_claim_processor', 
            claim_id, 
            '526EZ Claim Processor started')

        ClaimsApi::V2::DisabilityCompensationPdfGenerator.perform_async(claim_id)
        #log_job_progress('dis_comp_claim_processor', 
            # claim_id, 
            # '526EZ Claim Processor finished')
      end

      protected

      def get_claim(claim_id)
        ClaimsApi::AutoEstablishedClaim.find(claim_id)
      end

      def log_job_progress(tag, claim_id, detail)
        ClaimsApi::Logger.log(tag, 
            claim_id: claim_id, 
            detail: detail)
      end
    end
  end
end