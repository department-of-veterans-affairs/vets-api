# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
    def self.pending_attempts
      form_ids = AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::FORM_TYPES.map { |klass| klass::FORM_ID }

      FormSubmissionAttempt
        .joins(:form_submission)
        .where(aasm_state: 'pending')
        .merge(FormSubmission.where(form_type: form_ids))
    end

    private

    def claim_class
      ::SavedClaim
    end

    def monitor
      @monitor ||= AccreditedRepresentativePortal::Monitor.new(claim:)
    end

    def notification_email
      @notification_email ||= AccreditedRepresentativePortal::NotificationEmail.new(claim.id)
    end

    def on_failure
      @avoided = notification_email.deliver(:error)
      super
    end

    def on_success
      notification_email.deliver(:received)
      super
    end
  end
end
