# frozen_string_literal: true

# require 'sidekiq'
# require 'sidekiq/monitored_worker'
require 'claims_api/claim_logger'
# require 'claims_api/v2/disability_compensation_pdf_mapper'
# require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module V2
    class DisabilityCompensationClaimProcessor
      def perform(claim, target_veteran)
        byebug
        log_job_progress('dis_comp_claim_processor', 
                claim, 
                '526EZ claim processor started')
        @pdf_job = pdf_generator_service.perform(claim, target_veteran)

        return unless @pdf_job == 'finished'
        #
        log_job_progress('dis_comp_claim_processor', 
                claim, 
                '526EZ claim Docker container started')
        # docker = ClaimsApi::DockerContainer.perform_async

        #
        # @uploader ||= ClaimsApi::SupportingDocumentUploader.new(id)
      end

      protected

      def pdf_generator_service
        ClaimsApi::V2::DisabilityCompensationPdfGenerator.new
      end

      def log_job_progress(tag, claim, detail)
        ClaimsApi::Logger.log(tag, 
            claim_id: claim.id, 
            detail: detail)
      end
    end
  end
end