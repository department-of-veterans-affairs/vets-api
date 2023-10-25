# frozen_string_literal: true

require 'pdf_generator_service/pdf_client'
require 'bd/bd'

module ClaimsApi
  module V2
    class DisabilityCompensationBenefitsDocumentsUploader < DisabilityCompensationClaimServiceBase
      LOG_TAG = '526 v2 Benefits Documents Uploader job'

      def perform(claim_id) # rubocop:disable Metrics/MethodLength
        log_job_progress(LOG_TAG,
                         claim_id,
                         'BD upload job started')

        claim_object = ClaimsApi::SupportingDocument.find_by(id: claim_id) ||
                       ClaimsApi::AutoEstablishedClaim.find_by(id: claim_id)

        auto_claim = claim_object.try(:auto_established_claim) || claim_object

        # Reset for a rerun on this
        set_pending_state_on_claim(auto_claim) unless auto_claim.status == pending_state_value

        uploader = claim_object.uploader
        uploader.retrieve_from_store!(claim_object.file_data['filename'])
        file_body = uploader.read

        bd_upload_body(auto_claim:, file_body:)

        log_job_progress(LOG_TAG,
                         claim_id,
                         'Uploaded 526EZ PDF to BD')

        log_job_progress(LOG_TAG,
                         claim_id,
                         'BD upload succeeded')

        start_claim_establsher_job(auto_claim) if auto_claim.status != errored_state_value

      # Temporary errors (returning HTML, connection timeout), retry call
      rescue Faraday::Error::ParsingError, Faraday::TimeoutError => e
        set_errored_state_on_claim(auto_claim)
        log_job_progress(LOG_TAG,
                         claim_id,
                         "BD failure for claimId #{auto_claim&.id}: #{e.message}")
        log_exception_to_sentry(e)

        raise e
      rescue => e
        set_errored_state_on_claim(auto_claim)
        message = get_error_message(e)

        log_job_progress(LOG_TAG,
                         claim_id,
                         "BD failure for claimId #{auto_claim&.id}: #{message}")
        log_exception_to_sentry(e)

        raise e
      end

      private

      def start_claim_establsher_job(auto_claim)
        claim_establisher_service.perform_async(auto_claim&.id)
      end

      def claim_establisher_service
        ClaimsApi::V2::DisabilityCompensationClaimEstablisher
      end

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
