# frozen_string_literal: true

class SavedClaim::Form21p530a < SavedClaim
  FORM = '21P-530a'

  validates :form, presence: true

  def form_schema
    schema = JSON.parse(Openapi::Requests::Form21p530a::FORM_SCHEMA.to_json)
    schema['components'] = JSON.parse(Openapi::Components::ALL.to_json)
    schema
  end

  def process_attachments!
    Lighthouse::SubmitBenefitsIntakeClaim.perform_async(id)
  end

  def send_confirmation_email
    # Email functionality not included in MVP
    # recipient_email = parsed_form.dig('burialInformation', 'recipientOrganization', 'email')
    # return unless recipient_email

    # VANotify::EmailJob.perform_async(
    #   recipient_email,
    #   Settings.vanotify.services.va_gov.template_id.form21p530a_confirmation,
    #   {
    #     'organization_name' => organization_name,
    #     'veteran_name' => veteran_name,
    #     'confirmation_number' => confirmation_number,
    #     'date_submitted' => created_at.strftime('%B %d, %Y')
    #   }
    # )
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    [
      'Department of Veterans Affairs',
      'Pension Management Center',
      'P.O. Box 5365',
      'Janesville, WI 53547-5365'
    ].freeze
  end

  # Required for Lighthouse Benefits Intake API submission
  # PMC = Pension Management Center (handles burial benefits)
  def business_line
    'PMC'
  end

  # VBMS document type for burial allowance applications
  def document_type
    540 # Burial/Memorial Benefits
  end

  def attachment_keys
    # Form 21P-530a does not support attachments in MVP
    [].freeze
  end

  # Override to_pdf to add official signature stamp
  # This ensures the signature is included in both the download_pdf endpoint
  # and the Lighthouse Benefits Intake submission
  def to_pdf(file_name = nil, fill_options = {})
    PdfFill::Filler.fill_form(self, file_name, fill_options)
    # TODO: Add signature stamping when PdfFill::Forms::Va21p530a is implemented
    # PdfFill::Forms::Va21p530a.stamp_signature(pdf_path, parsed_form)
  end

  private

  def organization_name
    parsed_form.dig('burialInformation', 'recipientOrganization', 'name') ||
      parsed_form.dig('burialInformation', 'nameOfStateCemeteryOrTribalOrganization')
  end

  def veteran_name
    first = parsed_form.dig('veteranInformation', 'fullName', 'first')
    last = parsed_form.dig('veteranInformation', 'fullName', 'last')
    "#{first} #{last}".strip.presence
  end
end
