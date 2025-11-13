# frozen_string_literal: true

class SavedClaim::Form210779 < SavedClaim
  FORM = '21-0779'
  before_validation :duplicate_data_for_lighthouse

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

  def send_to_benefits_intake_api
    Lighthouse::SubmitBenefitsIntakeClaim.new.perform(id)
  end

  # Lighthouse::SubmitBenefitsIntakeClaim#generate_metadata makes the assumption that `claim.parsed_form`
  # has the following attributes:
  # {
  #   veteranFullName: {first: "", last: ""}
  #   vaFileNumber: "", # either vaFileNumber OR veteranSocialSecurityNumber if file number is null
  #   veteranSocialSecurityNumber: "",
  #   veteranAddress: {postalCode: ""} # or claimantAddress
  # }

  def duplicate_data_for_lighthouse
    unless parsed_form['veteranFullName']
      updated_form = parsed_form
      updated_form['veteranFullName'] = parsed_form.dig('veteranInformation', 'fullName')
      updated_form['veteranAddress'] = parsed_form.dig('nursingHomeInformation', 'nursingHomeAddress')
      updated_form['vaFileNumber'] = parsed_form.dig('veteranInformation', 'veteranId', 'vaFileNumber')
      updated_form['veteranSocialSecurityNumber'] = parsed_form.dig('veteranInformation', 'veteranId', 'ssn')
      @parsed_form = updated_form # because parsed_form memoizes
      self.form = updated_form.to_json
    end
  end
end
