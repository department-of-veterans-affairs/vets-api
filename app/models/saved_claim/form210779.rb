# frozen_string_literal: true

class SavedClaim::Form210779 < SavedClaim
  FORM = '21-0779'

  def process_attachments!
    # Form 21-0779 does not support user-uploaded attachments in MVP
    Lighthouse::SubmitBenefitsIntakeClaim.perform_async(id)
  end

  # Required for Lighthouse Benefits Intake API submission
  # CMP = Compensation (for disability claims)
  def business_line
    'CMP'
  end

  # VA Form 21-0779 - Request for Nursing Home Information in Connection with Claim for Aid & Attendance
  # see LighthouseDocument::DOCUMENT_TYPES
  def document_type
    222
  end

  def send_confirmation_email
    # Email functionality not included in MVP

    # VANotify::EmailJob.perform_async(
    #   employer_email,
    #   Settings.vanotify.services.va_gov.template_id.form210779_confirmation,
    #   {}
    # )
  end

  def veteran_name
    first = parsed_form.dig('veteranInformation', 'fullName', 'first')
    last = parsed_form.dig('veteranInformation', 'fullName', 'last')
    "#{first} #{last}".strip.presence || 'Veteran'
  end
end
