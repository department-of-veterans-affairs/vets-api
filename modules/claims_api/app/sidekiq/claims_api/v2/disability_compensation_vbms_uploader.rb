# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'
require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module V2
    class DisabilityCompensationVBMSUploader < DisabilityCompensationClaimService
      include Sidekiq::Job
      include SentryLogging
      include Sidekiq::MonitoredWorker

      def perform(claim_id) # rubocop:disable Metrics/MethodLength
        byebug
        log_job_progress('dis_comp_vbms_uploader',
                         claim_id,
                         'VBMS upload job started')

        claim_object = ClaimsApi::SupportingDocument.find_by(id: claim_id) ||
                       ClaimsApi::AutoEstablishedClaim.find_by(id: claim_id)

        auto_claim = claim_object.try(:auto_established_claim) || claim_object

        auto_claim.auth_headers
        uploader = claim_object.uploader
        uploader.retrieve_from_store!(claim_object.file_data['filename'])
        file_body = uploader.read

        bd_upload_body(auto_claim:, file_body:)

        log_job_progress('dis_comp_vbms_uploader',
                         claim_id,
                         'Uploaded 526EZ PDF to VBMS')

        unless @claim.status == 'errored'
          set_claim_as_established(auto_claim.id)
        end

        log_job_progress('dis_comp_vbms_uploader',
                         claim_id,
                         'VBMS uploaded succeeded, claim established')

      # Temporary errors (returning HTML, connection timeout), retry call
      rescue Faraday::Error::ParsingError, Faraday::TimeoutError => e
        log_job_progress('dis_comp_vbms_uploader',
                         auto_claim&.id,
                         "/upload failure for claimId #{auto_claim&.id}: #{e.message}, will retry")

        set_errored_state(e, auto_claim&.id)
        raise e
      # Permanent failures, don't retry
      rescue => e
        message = if e.respond_to? :original_body
                    e.original_body
                  else
                    e.message
                  end
        log_job_progress('benefits_documents',
                         auto_claim&.id,
                         "/upload failure for claimId #{auto_claim&.id}: #{message}, will not retry")

        set_errored_state(e, auto_claim&.id)
        {}
      end

      private

      def bd_upload_body(auto_claim:, file_body:)
        fh = Tempfile.new(['pdf_path', '.pdf'], binmode: true)
        begin
          fh.write(file_body)
          fh.close
          claim_bd_upload_document(auto_claim, fh.path)
        ensure
          fh.unlink
        end
      end

      def claim_bd_upload_document(claim, pdf_path)
        ClaimsApi::BD.new.upload(claim:, pdf_path:)
      end
    end
  end
end
