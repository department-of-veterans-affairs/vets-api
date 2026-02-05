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
      businessLine: business_line }
  end

  private

  def zip_code_for_metadata
    parsed_form.dig('burialInformation', 'recipientOrganization', 'address', 'postalCode') || DEFAULT_ZIP_CODE
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

  # Convert form data to IBM MMS VBA Data Dictionary format
  # @return [Hash] VBA Data Dictionary payload for form 21P-530A
  # Reference: /Users/calvincosta/Desktop/repos/va.gov-team/docs/VBA_Data_Dictionaries/OCT 2024 Data Dictionary-Table 1.csv
  def to_ibm
    build_ibm_payload(parsed_form)
  end

  # Build the IBM data dictionary payload from the parsed claim form
  # @param form [Hash]
  # @return [Hash]
  def build_ibm_payload(form)
    build_veteran_fields(form)
      .merge(build_service_period_fields(form))
      .merge(build_burial_fields(form))
      .merge(build_recipient_org_fields(form))
      .merge(build_certification_fields(form))
      .merge(build_metadata_fields(form))
  end

  # Build veteran identification fields (Boxes 1-7)
  # @param form [Hash]
  # @return [Hash]
  def build_veteran_fields(form)
    vet_info = form['veteranInformation'] || {}

    build_veteran_basic_fields(vet_info, full_name_field: 'VETERAN_NAME').merge(
      'VETERAN_SERVICE_NUMBER' => vet_info['vaServiceNumber'],
      'VETERAN_PLACE_OF_BIRTH' => vet_info['placeOfBirth'],
      'VETERAN_DATE_OF_DEATH' => format_date_for_ibm(vet_info['dateOfDeath'])
    )
  end

  # Build service period fields (Boxes 8-10) - supports up to 3 periods
  # @param form [Hash]
  # @return [Hash]
  def build_service_period_fields(form)
    service_periods = form['veteranServicePeriods'] || {}
    periods = service_periods['periods'] || []

    {
      'BRANCH_OF_SERVICE_1' => periods.dig(0, 'serviceBranch'),
      'DATE_ENTERED_TO_SERVICE_1' => format_date_for_ibm(periods.dig(0, 'dateEnteredService')),
      'PLACE_ENTERED_TO_SERVICE_1' => periods.dig(0, 'placeEnteredService'),
      'GRADE_RANK_1' => periods.dig(0, 'rankAtSeparation'),
      'SEPARATION_DATE_1' => format_date_for_ibm(periods.dig(0, 'dateLeftService')),
      'SEPARATION_PLACE_1' => periods.dig(0, 'placeLeftService'),
      'BRANCH_OF_SERVICE_2' => periods.dig(1, 'serviceBranch'),
      'DATE_ENTERED_TO_SERVICE_2' => format_date_for_ibm(periods.dig(1, 'dateEnteredService')),
      'PLACE_ENTERED_TO_SERVICE_2' => periods.dig(1, 'placeEnteredService'),
      'GRADE_RANK_2' => periods.dig(1, 'rankAtSeparation'),
      'SEPARATION_DATE_2' => format_date_for_ibm(periods.dig(1, 'dateLeftService')),
      'SEPARATION_PLACE_2' => periods.dig(1, 'placeLeftService'),
      'BRANCH_OF_SERVICE_3' => periods.dig(2, 'serviceBranch'),
      'DATE_ENTERED_TO_SERVICE_3' => format_date_for_ibm(periods.dig(2, 'dateEnteredService')),
      'PLACE_ENTERED_TO_SERVICE_3' => periods.dig(2, 'placeEnteredService'),
      'GRADE_RANK_3' => periods.dig(2, 'rankAtSeparation'),
      'SEPARATION_DATE_3' => format_date_for_ibm(periods.dig(2, 'dateLeftService')),
      'SEPARATION_PLACE_3' => periods.dig(2, 'placeLeftService'),
      'VET_NAME_OTHER' => service_periods['servedUnderDifferentName']
    }
  end

  # Build burial information fields (Boxes 11-13)
  # @param form [Hash]
  # @return [Hash]
  def build_burial_fields(form)
    burial_info = form['burialInformation'] || {}
    place_of_burial = burial_info['placeOfBurial'] || {}
    cemetery_location = place_of_burial['cemeteryLocation'] || {}

    {
      'ORG_CLAIMING_ALLOWANCE' => burial_info['nameOfStateCemeteryOrTribalOrganization'],
      'CEMETERY_NAME' => place_of_burial['stateCemeteryOrTribalCemeteryName'],
      'CEMETERY_LOCATION' => build_cemetery_location(cemetery_location),
      'VETERAN_DATE_OF_BURIAL' => format_date_for_ibm(burial_info['dateOfBurial'])
    }
  end

  # Build recipient organization fields (Boxes 14-16)
  # @param form [Hash]
  # @return [Hash]
  def build_recipient_org_fields(form)
    burial_info = form['burialInformation'] || {}
    recipient_org = burial_info['recipientOrganization'] || {}
    recipient_addr = recipient_org['address'] || {}

    {
      'REP_NAME' => recipient_org['name'],
      'REP_PHONE_NUMBER' => format_phone_for_ibm(recipient_org['phoneNumber'])
    }.merge(build_address_fields(recipient_addr, 'REP_ADDRESS'))
  end

  # Build certification fields (Box 17)
  # @param form [Hash]
  # @return [Hash]
  def build_certification_fields(form)
    burial_info = form['burialInformation'] || {}

    {
      'OFFICIAL_SIGNATURE' => burial_info['officialSignature'],
      'OFFICIAL_TITLE' => burial_info['officialTitle'],
      'DATE_SIGNED' => format_date_for_ibm(burial_info['dateSigned']),
      'REMARKS' => form['remarks']
    }
  end

  # Build form metadata fields
  # @param form [Hash]
  # @return [Hash]
  def build_metadata_fields(form)
    vet_info = form['veteranInformation'] || {}

    build_form_metadata('21P-530a', {
                          'VETERAN_SSN_1' => vet_info['ssn']
                        })
  end

  # Build cemetery location string from location hash
  # @param location_hash [Hash, nil]
  # @return [String, nil]
  def build_cemetery_location(location_hash)
    return nil unless location_hash

    parts = [location_hash['city'], location_hash['state']].compact
    parts.join(', ').strip.presence
  end
end
