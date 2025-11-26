# frozen_string_literal: true

class SavedClaim::Form214192 < SavedClaim
  FORM = '21-4192'
  DEFAULT_ZIP_CODE = '00000'

  validates :form, presence: true

  def form_schema
    schema = JSON.parse(Openapi::Requests::Form214192::FORM_SCHEMA.to_json)
    schema['components'] = JSON.parse(Openapi::Components::ALL.to_json)
    schema
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
    [].freeze
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

  # Override to_pdf to add employer signature stamp
  # This ensures the signature is included in both the download_pdf endpoint
  # and the Lighthouse Benefits Intake submission
  def to_pdf(file_name = nil, fill_options = {})
    pdf_path = PdfFill::Filler.fill_form(self, file_name, fill_options)
    PdfFill::Forms::Va214192.stamp_signature(pdf_path, parsed_form)
  end

  def metadata_for_benefits_intake
    { veteranFirstName: parsed_form.dig('veteranInformation', 'fullName', 'first'),
      veteranLastName: parsed_form.dig('veteranInformation', 'fullName', 'last'),
      fileNumber: parsed_form.dig('veteranInformation', 'vaFileNumber') || parsed_form.dig('veteranInformation', 'ssn'),
      zipCode: zip_code_for_metadata,
      businessLine: business_line }
  end

  private

  def zip_code_for_metadata
    parsed_form.dig('employmentInformation', 'employerAddress', 'postalCode') || DEFAULT_ZIP_CODE
  end

  def employer_name
    parsed_form.dig('employmentInformation', 'employerName') || 'Employer'
  end

  def veteran_name
    first = parsed_form.dig('veteranInformation', 'fullName', 'first')
    last = parsed_form.dig('veteranInformation', 'fullName', 'last')
    "#{first} #{last}".strip.presence || 'Veteran'
  end
end
