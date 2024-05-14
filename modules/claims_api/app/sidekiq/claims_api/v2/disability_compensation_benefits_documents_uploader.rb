# frozen_string_literal: true

require 'claims_api/v2/mock_526_pdf_generator'
require 'pdf_generator_service/pdf_client'
require 'bd/bd'

module ClaimsApi
  module V2
    class DisabilityCompensationBenefitsDocumentsUploader < ClaimsApi::ServiceBase
      LOG_TAG = '526_v2_Benefits_Documents_Uploader_job'

      def perform(claim_id) # rubocop:disable Metrics/MethodLength
        log_job_progress(claim_id,
                         'BD upload job started')

        auto_claim = get_claim(claim_id)

        # Reset for a rerun on this
        set_pending_state_on_claim(auto_claim) unless auto_claim.status == pending_state_value

        file_body = if Settings.claims_api.pdf_generator_526.mock == false
                      uploader = auto_claim.uploader
                      uploader.retrieve_from_store!(auto_claim.file_data['filename'])
                      uploader.read
                    else
                      File.read('modules/claims_api/lib/claims_api/v2/mock_526_pdf.pdf')
                    end

        bd_upload_body(auto_claim:, file_body:)

        log_job_progress(claim_id,
                         'Uploaded 526EZ PDF to BD')
        # at this point in the workflow the claim is 'established'
        set_established_state_on_claim(auto_claim)
        log_job_progress(claim_id,
                         'BD upload succeeded, Claim workflow finished')
      # Temporary errors (returning HTML, connection timeout), retry call
      rescue => e
        error_message = get_error_message(e)
        log_job_progress(claim_id,
                         "BD failure #{e.class}: #{error_message}")
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
