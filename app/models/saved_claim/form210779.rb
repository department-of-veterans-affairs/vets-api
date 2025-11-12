# frozen_string_literal: true

class SavedClaim::Form210779 < SavedClaim
  FORM = '21-0779'

  def process_attachments!
    # Form 21-0779 does not support attachments in MVP
    # Lighthouse::SubmitBenefitsIntakeClaim.perform_async(id)
  end

  def send_confirmation_email
    # Email functionality not included in MVP

    # VANotify::EmailJob.perform_async(
    #   employer_email,
    #   Settings.vanotify.services.va_gov.template_id.form210779_confirmation,
    #   {}
    # )
  end
end
