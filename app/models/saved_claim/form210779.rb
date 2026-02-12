# frozen_string_literal: true

class SavedClaim::Form210779 < SavedClaim
  include IbmDataDictionary

  FORM = '21-0779'
  NURSING_HOME_DOCUMENT_TYPE = 222

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
    NURSING_HOME_DOCUMENT_TYPE
  end

  def send_confirmation_email
    # Email functionality not included in MVP

    # VANotify::EmailJob.perform_async(
    #   employer_email,
    #   Settings.vanotify.services.va_gov.template_id.form210779_confirmation,
    #   {}
    # )
  end

  # Override to_pdf to add nursing home official signature stamp
  def to_pdf(file_name = nil, fill_options = {})
    pdf_path = PdfFill::Filler.fill_form(self, file_name, fill_options)
    PdfFill::Forms::Va210779.stamp_signature(pdf_path, parsed_form)
  end

  def veteran_name
    first = parsed_form.dig('veteranInformation', 'fullName', 'first')
    last = parsed_form.dig('veteranInformation', 'fullName', 'last')
    "#{first} #{last}".strip.presence || 'Veteran'
  end

  def metadata_for_benefits_intake
    { veteranFirstName: parsed_form.dig('veteranInformation', 'fullName', 'first'),
      veteranLastName: parsed_form.dig('veteranInformation', 'fullName', 'last'),
      fileNumber: parsed_form.dig('veteranInformation', 'veteranId', 'ssn'),
      zipCode: zip_code_for_metadata,
      businessLine: business_line,
      docType: "StructuredData:#{FORM}" }
  end

  # Convert form data to IBM MMS VBA Data Dictionary format
  # @return [Hash] VBA Data Dictionary payload for form 21-0779
  # Reference: 0779 Data Dictionary Test Final (1).xlsx
  def to_ibm
    build_ibm_payload(parsed_form)
  end

  private

  def zip_code_for_metadata
    parsed_form.dig('nursingHomeInformation', 'nursingHomeAddress', 'postalCode')
  end

  # Build the IBM data dictionary payload from the parsed claim form
  # @param form [Hash]
  # @return [Hash]
  def build_ibm_payload(form)
    build_veteran_fields(form)
      .merge(build_claimant_fields_section(form))
      .merge(build_nursing_home_fields(form))
      .merge(build_form_metadata_fields)
  end

  # Build veteran identification fields (Section I)
  # @param form [Hash]
  # @return [Hash]
  def build_veteran_fields(form)
    vet_info = form['veteranInformation'] || {}
    vet_id = vet_info['veteranId'] || {}

    build_veteran_basic_fields(vet_info)
      .merge({
        'VETERAN_SSN' => vet_id['ssn'],
        'VA_FILE_NUMBER' => vet_id['vaFileNumber']
      }.compact)
  end

  # Build claimant information fields (Section II - Boxes 5-8)
  # @param form [Hash]
  # @return [Hash]
  def build_claimant_fields_section(form)
    claimant_info = form['claimantInformation'] || {}

    fields = build_claimant_fields(claimant_info)

    # Box 7: VA File Number (note the typo from the spec: CL_FILE_NUMER)
    fields['CL_FILE_NUMER'] = claimant_info['vaFileNumber'] if claimant_info['vaFileNumber']

    fields
  end

  # Build nursing home information fields (Section III - Boxes 9-21)
  # @param form [Hash]
  # @return [Hash]
  # rubocop:disable Metrics/MethodLength
  def build_nursing_home_fields(form)
    nursing_home = form['nursingHomeInformation'] || {}
    nursing_address = nursing_home['nursingHomeAddress'] || {}

    fields = {}

    # Box 9: Name of nursing home
    fields['NAME_FACILITY_C'] = nursing_home['nursingHomeName']

    # Box 10: Address of nursing home
    fields['FACILITY_ADDRESS_LINE1_C'] = nursing_address['street']
    fields['FACILITY_ADDRESS_LINE2_C'] = nursing_address['street2']
    fields['FACILITY_ADDRESS_CITY_C'] = nursing_address['city']
    fields['FACILITY_ADDRESS_STATE_C'] = nursing_address['state']
    fields['FACILITY_ADDRESS_COUNTRY_C'] = nursing_address['country']
    fields['FACILITY_ADDRESS_ZIP_C'] = nursing_address['postalCode']

    # Box 11: Date admitted to nursing home (MM/DD/YYYY format)
    if nursing_home['admissionDate']
      fields['DATE_ADMISSION_TO_FACILITY_C'] =
        format_date_for_ibm(nursing_home['admissionDate'])
    end

    # Box 12: Is the nursing home a Medicaid approved facility?
    if nursing_home['medicaidApproved'].present?
      fields['MEDICAID_APPROVED_Y'] = build_checkbox_value(nursing_home['medicaidApproved'] == true)
      fields['MEDICAID_APPROVED_N'] = build_checkbox_value(nursing_home['medicaidApproved'] == false)
    end

    # Box 13: Has the patient applied for Medicaid?
    if nursing_home['medicaidApplied'].present?
      fields['MEDICAID_APPLIED_Y'] = build_checkbox_value(nursing_home['medicaidApplied'] == true)
      fields['MEDICAID_APPLIED_N'] = build_checkbox_value(nursing_home['medicaidApplied'] == false)
    end

    # Box 14A: Is the patient covered by Medicaid?
    if nursing_home['medicaidCoverage'].present?
      fields['MEDICAID_COVERAGE_Y'] = build_checkbox_value(nursing_home['medicaidCoverage'] == true)
      fields['MEDICAID_COVERAGE_N'] = build_checkbox_value(nursing_home['medicaidCoverage'] == false)
    end

    # Box 14B: Date Medicaid plan began (MM/DD/YYYY format)
    if nursing_home['medicaidStartDate']
      fields['MEDICAID_START'] =
        format_date_for_ibm(nursing_home['medicaidStartDate'])
    end

    # Box 15: Monthly amount patient is responsible for out of pocket
    fields['OUT_OF_POCKET'] = nursing_home['monthlyOutOfPocket']

    # Box 16: Type of care (skilled or intermediate)
    if nursing_home['typeOfCare'].present?
      fields['SKILLED_CARE'] = build_checkbox_value(nursing_home['typeOfCare'] == 'skilled')
      fields['INTERMEDIATE_CARE'] = build_checkbox_value(nursing_home['typeOfCare'] == 'intermediate')
    end

    # Box 17: Nursing home official's name
    fields['NAME_COMPLETING_WORKSHEET_C'] = nursing_home['officialName']

    # Box 18: Nursing home official's title
    fields['ROLE_PERFORM_AT_FACILITY_C'] = nursing_home['officialTitle']

    # Box 19: Nursing home official's office telephone number
    fields['FACILITY_TELEPHONE_NUMBER_C'] = format_phone_for_ibm(nursing_home['officialPhone'])
    if nursing_home['internationalPhone']
      fields['INT_PHONE_NUMBER'] =
        format_phone_for_ibm(nursing_home['internationalPhone'])
    end

    # Box 20: Signature of nursing home official (handled in PDF stamping)
    fields['SIGNATURE_OF_PROVIDER_C'] = nursing_home['officialSignature']

    # Box 21: Date signed (MM/DD/YYYY format)
    if nursing_home['signatureDate']
      fields['SIGNATURE_DATE_PROVIDER_C'] =
        format_date_for_ibm(nursing_home['signatureDate'])
    end

    fields.compact
  end
  # rubocop:enable Metrics/MethodLength

  # Build form metadata
  # @return [Hash]
  def build_form_metadata_fields
    {
      'FORM_TYPE' => '21-0779',
      'FORM_TYPE_1' => '21-0779'
    }
  end
end
