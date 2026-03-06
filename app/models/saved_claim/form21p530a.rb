# frozen_string_literal: true

class SavedClaim::Form21p530a < SavedClaim
  include IbmDataDictionary

  FORM = '21P-530a'
  DEFAULT_ZIP_CODE = '00000'

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
    pdf_path = PdfFill::Filler.fill_form(self, file_name, fill_options)
    PdfFill::Forms::Va21p530a.stamp_signature(pdf_path, parsed_form)
  end

  # Required metadata format for Lighthouse Benefits Intake API submission
  # This method extracts veteran identity information and organization address
  # to ensure proper routing and indexing in VBMS
  def metadata_for_benefits_intake
    { veteranFirstName: parsed_form.dig('veteranInformation', 'fullName', 'first'),
      veteranLastName: parsed_form.dig('veteranInformation', 'fullName', 'last'),
      fileNumber: parsed_form.dig('veteranInformation', 'vaFileNumber') || parsed_form.dig('veteranInformation', 'ssn'),
      zipCode: zip_code_for_metadata,
      businessLine: business_line,
      docType: "StructuredData:#{FORM}" }
  end

  # Convert form data to IBM GCIO VBA Data Dictionary format
  # Returns ONLY the 17 fields defined in the VA Forms - Data Dictionary
  # Mapping based on Form 21P-530a OCT 2024 Data Dictionary
  def to_ibm
    vet_info = parsed_form['veteranInformation'] || {}
    burial_info = parsed_form['burialInformation'] || {}
    place_of_burial = burial_info['placeOfBurial'] || {}
    certification = parsed_form['certification'] || {}

    build_ibm_hash(vet_info, burial_info, place_of_burial, certification)
  end

  def organization_name
    parsed_form.dig('burialInformation', 'recipientOrganization', 'name') ||
      parsed_form.dig('burialInformation', 'nameOfStateCemeteryOrTribalOrganization')
  end

  def veteran_name
    first = parsed_form.dig('veteranInformation', 'fullName', 'first')
    last = parsed_form.dig('veteranInformation', 'fullName', 'last')
    "#{first} #{last}".strip.presence
  end

  def zip_code_for_metadata
    parsed_form.dig('burialInformation', 'recipientOrganization', 'address', 'postalCode') || DEFAULT_ZIP_CODE
  end

  private

  # Build the IBM VBA Data Dictionary hash with all 17 required fields
  # @param vet_info [Hash] Veteran information from parsed form
  # @param burial_info [Hash] Burial information from parsed form
  # @param place_of_burial [Hash] Place of burial from parsed form
  # @param certification [Hash] Certification information from parsed form
  # @return [Hash] VBA Data Dictionary payload
  def build_ibm_hash(vet_info, burial_info, place_of_burial, certification)
    full_name = vet_info['fullName'] || {}

    build_veteran_fields(vet_info, full_name)
      .merge(build_burial_fields(burial_info, place_of_burial))
      .merge(build_certification_fields(certification))
  end

  def build_veteran_fields(vet_info, full_name)
    {
      'VETERAN_FIRST_NAME' => full_name['first'],
      'VETERAN_MIDDLE_INITIAL' => extract_middle_initial(full_name['middle']),
      'VETERAN_LAST_NAME' => full_name['last'],
      'VETERAN_NAME' => build_full_name(full_name),
      'VETERAN_SSN' => vet_info['ssn'],
      'VETERAN_SERVICE_NUMBER' => vet_info['vaServiceNumber'],
      'VA_FILE_NUMBER' => vet_info['vaFileNumber'],
      'VETERAN_DOB' => format_date_for_ibm(vet_info['dateOfBirth']),
      'VETERAN_DATE_OF_DEATH' => format_date_for_ibm(vet_info['dateOfDeath'])
    }
  end

  def build_burial_fields(burial_info, place_of_burial)
    {
      'ORG_CLAIMING_ALLOWANCE' => burial_info['nameOfStateCemeteryOrTribalOrganization'],
      'CEMETERY_NAME' => place_of_burial['stateCemeteryOrTribalCemeteryName'],
      'CEMETERY_LOCATION' => place_of_burial['stateCemeteryOrTribalCemeteryLocation'],
      'VETERAN_DATE_OF_BURIAL' => format_date_for_ibm(burial_info['dateOfBurial'])
    }
  end

  def build_certification_fields(certification)
    date_signed = certification['dateSigned'] || parsed_form['dateSigned'] || created_at&.to_date&.iso8601

    {
      'FORM_TYPE_1' => 'VA FORM 21P-530a, OCT 2024',
      'OFFICIAL_SIGNATURE' => certification['signature'],
      'DATE_SIGNED' => format_date_for_ibm(date_signed),
      'FORM_TYPE' => 'VA FORM 21P-530a, OCT 2024'
    }
  end
end
