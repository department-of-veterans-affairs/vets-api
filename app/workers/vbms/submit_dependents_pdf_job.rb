# frozen_string_literal: true

module VBMS
  class SubmitDependentsPDFJob
    include Sidekiq::Worker
    include SentryLogging

    # Generates PDF for 686c form and uploads to VBMS
    def perform(saved_claim_id, veteran_info)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      claim.format_and_upload_pdf(veteran_info)
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
