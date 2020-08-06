# frozen_string_literal: true

module VBMS
  class SubmitDependentsPDFJob
    class Invalid686cClaim < StandardError; end
    include Sidekiq::Worker
    include SentryLogging

    # Generates PDF for 686c form and uploads to VBMS
    def perform(saved_claim_id, va_file_number_with_payload)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      claim.add_veteran_info(va_file_number_with_payload)

      raise Invalid686cClaim unless claim.valid?(:pdf_upload_job)

      claim.upload_pdf
    rescue => e
      send_error_to_sentry(e, claim&.id)
    end

    private

    def send_error_to_sentry(error, saved_claim_id)
      log_exception_to_sentry(
        error,
        {
          claim_id: saved_claim_id
        },
        { team: 'vfs-ebenefits' }
      )
    end
  end
end
