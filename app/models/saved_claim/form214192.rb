# frozen_string_literal: true

class SavedClaim::Form214192 < SavedClaim
  FORM = '21-4192'

  validates :form, presence: true
  validates_with Form214192Validator

  # Skip JSON schema validation since we're using custom validator and moving away from vets-json-schema
  def form_matches_schema
    # Custom validation handled by Form214192Validator
    true
  end

  def process_attachments!
    # Form 21-4192 does not support attachments in MVP
    # This form is completed by employers providing employment information
    # No supporting documents are collected as part of the form submission
    Lighthouse::SubmitBenefitsIntakeClaim.perform_async(id)
  end

  def send_confirmation_email
    # Email functionality not included in MVP
    # employer_email = parsed_form.dig('employmentInformation', 'employerEmail')
    # return unless employer_email

    # VANotify::EmailJob.perform_async(
    #   employer_email,
    #   Settings.vanotify.services.va_gov.template_id.form214192_confirmation,
    #   {
    #     'employer_name' => employer_name,
    #     'veteran_name' => veteran_name,
    #     'confirmation_number' => confirmation_number,
    #     'date_submitted' => created_at.strftime('%B %d, %Y')
    #   }
    # )
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    []
  end

  # Required for Lighthouse Benefits Intake API submission
  # CMP = Compensation (for disability claims)
  def business_line
    'CMP'
  end

  # VBMS document type for employment information
  def document_type
    119 # Request for Employment Information
  end

  def attachment_keys
    # Form 21-4192 does not support attachments in MVP
    [].freeze
  end

  private

  def employer_name
    parsed_form.dig('employmentInformation', 'employerName') || 'Employer'
  rescue => e
    'Employer'
  end

  def veteran_name
    "#{parsed_form.dig('veteranInformation', 'fullName',
                       'first')} #{parsed_form.dig('veteranInformation', 'fullName', 'last')}"
  rescue => e
    'Veteran'
  end
end
