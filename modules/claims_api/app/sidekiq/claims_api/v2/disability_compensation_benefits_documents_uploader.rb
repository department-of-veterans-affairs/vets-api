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

        auto_claim = get_claim(claim_id)

        # Reset for a rerun on this
        set_pending_state_on_claim(auto_claim) unless auto_claim.status == pending_state_value

        uploader = auto_claim.uploader
        uploader.retrieve_from_store!(auto_claim.file_data['filename'])
        file_body = uploader.read

        bd_upload_body(auto_claim:, file_body:)

        log_job_progress(LOG_TAG,
                         claim_id,
                         'Uploaded 526EZ PDF to BD')
        # at this point in the workflow the claim is 'established'
        set_established_state_on_claim(auto_claim)
        log_job_progress(LOG_TAG,
                         claim_id,
                         'BD upload succeeded, Claim workflow finished')
      # Temporary errors (returning HTML, connection timeout), retry call
      rescue Faraday::Error::ParsingError, Faraday::TimeoutError => e
        log_job_progress(LOG_TAG,
                         claim_id,
                         "BD failure for claimId #{auto_claim&.id}: #{e.message}")
        log_exception_to_sentry(e)

        raise e
      rescue => e
        message = get_error_message(e)

        log_job_progress(LOG_TAG,
                         claim_id,
                         "BD failure for claimId #{auto_claim&.id}: #{message}")
        log_exception_to_sentry(e)

        raise e
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
