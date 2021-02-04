# frozen_string_literal: true

module VBMS
  class SubmitDependentsPdfJob
    class Invalid686cClaim < StandardError; end
    include Sidekiq::Worker
    include SentryLogging

    # Generates PDF for 686c form and uploads to VBMS
    def perform(saved_claim_id, va_file_number_with_payload, submittable_686, submittable_674)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      claim.add_veteran_info(va_file_number_with_payload)

      raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

      claim.persistent_attachments.each do |attachment|
        claim.upload_to_vbms(path: "tmp#{attachment.file_url}")
      end

      generate_pdf(claim, submittable_686, submittable_674)
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

    def generate_pdf(claim, submittable_686, submittable_674)
      claim.upload_pdf('686C-674') if submittable_686
      claim.upload_pdf('21-674', doc_type: '143') if submittable_674
    end
  end
end
