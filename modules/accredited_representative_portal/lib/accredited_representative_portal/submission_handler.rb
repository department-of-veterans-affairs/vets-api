# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
    def self.pending_attempts
      Lighthouse::SubmissionAttempt.joins(:submission).where(
        status: 'pending',
        'lighthouse_submissions.form_id' => AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim::PROPER_FORM_ID
      )
    end

    private

    def claim_class
      ::SavedClaim
    end

    def monitor
      @monitor ||= AccreditedRepresentativePortal::Monitor.new
    end

    def notification_email
      @notification_email ||= AccreditedRepresentativePortal::NotificationEmail.new(claim.id)
    end

    def on_failure
      @avoided = notification_email.deliver(:error)
      super
    end
  end
end
