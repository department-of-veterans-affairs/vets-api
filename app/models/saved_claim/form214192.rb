# frozen_string_literal: true

class SavedClaim::Form214192 < SavedClaim
  include IbmDataDictionary

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

  # Convert form data to IBM MMS VBA Data Dictionary format
  # @return [Hash] VBA Data Dictionary payload for form 21-4192
  # Reference: AUG2024-Table 1.csv
  def to_ibm
    build_ibm_payload(parsed_form)
  end

  # Build the IBM data dictionary payload from the parsed claim form
  # @param form [Hash]
  # @return [Hash]
  def build_ibm_payload(form)
    build_veteran_fields(form)
      .merge(build_employer_fields(form))
      .merge(build_form_metadata_fields)
  end

  # Build veteran identification fields (Section 1)
  # @param form [Hash]
  # @return [Hash]
  def build_veteran_fields(form)
    vet_info = form['veteranInformation'] || {}

    # Use VETERAN_INITIAL instead of VETERAN_MIDDLE_INITIAL for this form
    basic_fields = build_veteran_basic_fields(vet_info)
    basic_fields['VETERAN_INITIAL'] = basic_fields.delete('VETERAN_MIDDLE_INITIAL')

    basic_fields
  end

  # Build employer information fields (Box 1)
  # @param form [Hash]
  # @return [Hash]
  def build_employer_fields(form)
    employment = form['employmentInformation'] || {}
    employer_address = employment['employerAddress'] || {}

    {
      'EMPLOYER_NAME_ADDRESS' => build_employer_name_and_address(employment['employerName'], employer_address)
    }.compact
  end

  # Build form metadata
  # @return [Hash]
  def build_form_metadata_fields
    build_form_metadata('4192')
  end

  # Build employer name and address as single field
  # @param name [String, nil]
  # @param addr_hash [Hash, nil]
  # @return [String, nil]
  def build_employer_name_and_address(name, addr_hash)
    parts = [name, build_full_address(addr_hash)].compact
    parts.join(', ').strip.presence
  end
end
