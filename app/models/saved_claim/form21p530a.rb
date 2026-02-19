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
  # Mapping based on Form 21P-530a OCT 2024 Data Dictionary
  def to_ibm
    ibm_data = {}
    ibm_data.merge!(build_veteran_fields)
    ibm_data.merge!(build_service_history_fields)
    ibm_data.merge!(build_burial_fields)
    ibm_data.merge!(build_recipient_organization_fields)
    ibm_data.merge!(build_signature_fields)
    ibm_data.merge!(build_form_metadata_fields)
    ibm_data
  end

  private

  def zip_code_for_metadata
    parsed_form.dig('burialInformation', 'recipientOrganization', 'address', 'postalCode') || DEFAULT_ZIP_CODE
  end

  # Format place of birth from object to string
  def format_place_of_birth(place_of_birth)
    return nil unless place_of_birth.is_a?(Hash)

    city = place_of_birth['city']
    state = place_of_birth['state']
    return nil unless city && state

    "#{city}, #{state}"
  end

  # Build veteran identification fields (Boxes 1-7)
  def build_veteran_fields
    full_name = parsed_form.dig('veteranInformation', 'fullName') || {}
    {
      'VETERAN_FIRST_NAME' => full_name['first'],
      'VETERAN_MIDDLE_INITIAL' => extract_middle_initial(full_name['middle']),
      'VETERAN_LAST_NAME' => full_name['last'],
      'VETERAN_FULL_NAME' => build_full_name(full_name),
      'VETERAN_SSN' => parsed_form.dig('veteranInformation', 'ssn'),
      'VETERAN_SERVICE_NUMBER' => parsed_form.dig('veteranInformation', 'vaServiceNumber'),
      'VA_FILE_NUMBER' => parsed_form.dig('veteranInformation', 'vaFileNumber'),
      'VETERAN_DOB' => format_date_for_ibm(parsed_form.dig('veteranInformation', 'dateOfBirth')),
      'VETERAN_PLACE_OF_BIRTH' => format_place_of_birth(parsed_form.dig('veteranInformation', 'placeOfBirth')),
      'VETERAN_DATE_OF_DEATH' => format_date_for_ibm(parsed_form.dig('veteranInformation', 'dateOfDeath'))
    }
  end

  # Build service history fields (Boxes 8-10)
  def build_service_history_fields
    service_periods = parsed_form['periods'] || parsed_form.dig('veteranServicePeriods', 'periods') || []
    fields = {}

    # Always create all 3 service period slots (Box 8-9)
    (1..3).each do |suffix|
      period = service_periods[suffix - 1] || {}
      fields["BRANCH_OF_SERVICE_#{suffix}"] = period['serviceBranch']
      fields["DATE_ENTERED_TO_SERVICE_#{suffix}"] = format_date_for_ibm(period['dateEnteredService'])
      fields["PLACE_ENTERED_TO_SERVICE_#{suffix}"] = period['placeEnteredService']
      fields["GRADE_RANK_#{suffix}"] = period['rankAtSeparation']
      fields["SEPARATION_DATE_#{suffix}"] = format_date_for_ibm(period['dateLeftService'])
      fields["SEPARATION_PLACE_#{suffix}"] = period['placeLeftService']
    end

    # Box 10 - Veteran served under other name
    fields['VET_NAME_OTHER'] = parsed_form.dig('veteranServicePeriods', 'servedUnderDifferentName')

    fields
  end

  # Build burial information fields (Boxes 11-13)
  def build_burial_fields
    burial_info = parsed_form['burialInformation'] || {}
    place_of_burial = burial_info['placeOfBurial'] || {}
    {
      'ORG_CLAIMING_ALLOWANCE' => burial_info['nameOfStateCemeteryOrTribalOrganization'],
      'CEMETERY_NAME' => place_of_burial['stateCemeteryOrTribalCemeteryName'],
      'CEMETERY_LOCATION' => place_of_burial['stateCemeteryOrTribalCemeteryLocation'],
      'VETERAN_DATE_OF_BURIAL' => format_date_for_ibm(burial_info['dateOfBurial'])
    }
  end

  # Build recipient organization fields (Boxes 14-16)
  def build_recipient_organization_fields
    recipient_org = parsed_form.dig('burialInformation', 'recipientOrganization') || {}
    address = recipient_org['address'] || {}

    {
      'REP_NAME' => recipient_org['name'],
      'REP_PHONE_NUMBER' => recipient_org['phoneNumber'],
      'REP_ADDRESS_LINE1' => address['streetAndNumber'],
      'REP_ADDRESS_LINE2' => address['aptOrUnitNumber'],
      'REP_ADDRESS_CITY' => address['city'],
      'REP_ADDRESS_STATE' => address['state'],
      'REP_ADDRESS_ZIP5' => address['postalCode'],
      'REP_ADDRESS' => format_recipient_address(address)
    }
  end

  # Build signature and remarks fields (Boxes 17-18)
  def build_signature_fields
    certification = parsed_form['certification'] || {}
    {
      'OFFICIAL_SIGNATURE' => certification['signature'],
      'OFFICIAL_TITLE' => certification['titleOfStateOrTribalOfficial'],
      'DATE_SIGNED' => format_date_for_ibm(created_at&.to_date),
      'REMARKS' => parsed_form['remarks'],
      'VETERAN_SSN_1' => parsed_form.dig('veteranInformation', 'ssn')
    }
  end

  # Build form metadata fields
  def build_form_metadata_fields
    {
      'FORM_TYPE' => FORM,
      'FORM_TYPE_1' => FORM,
      'SUPERSEDES VA FORM 21P-530A, AUG 2022' => 'SUPERSEDES VA FORM 21P-530A, AUG 2022'
    }
  end

  # Format full address for recipient organization (different field names than default)
  def format_recipient_address(address)
    return nil unless address

    parts = [
      address['streetAndNumber'],
      address['aptOrUnitNumber'],
      address['city'],
      address['state'],
      address['postalCode']
    ].compact.reject(&:empty?)

    parts.join(', ').presence
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
end
