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
      zipCode: parsed_form.dig('nursingHomeInformation', 'nursingHomeAddress', 'postalCode'),
      businessLine: business_line }
  end

  # Convert form data to IBM MMS VBA Data Dictionary format
  # @return [Hash] VBA Data Dictionary payload for form 21-0779
  # Reference: 0779-SEP2023-Table 1.csv
  def to_ibm
    build_ibm_payload(parsed_form)
  end

  private

  # Build the IBM data dictionary payload from the parsed claim form
  # @param form [Hash]
  # @return [Hash]
  def build_ibm_payload(form)
    build_veteran_fields(form)
      .merge(build_claimant_info_fields(form))
      .merge(build_nursing_home_fields(form))
      .merge(build_medicaid_fields(form))
      .merge(build_care_type_fields(form))
      .merge(build_official_fields(form))
      .merge(build_form_metadata_fields)
  end

  # Build veteran identification fields (Boxes 1-4)
  # @param form [Hash]
  # @return [Hash]
  def build_veteran_fields(form)
    vet_info = form['veteranInformation'] || {}

    build_veteran_basic_fields(vet_info).merge(
      'VETERAN_SERVICE_NUMBER' => vet_info['veteranServiceNumber']
    )
  end

  # Build claimant information fields (Boxes 5-8)
  # @param form [Hash]
  # @return [Hash]
  def build_claimant_info_fields(form)
    claimant_info = form['claimantInformation'] || {}

    build_claimant_fields(claimant_info).merge(
      'CL_FILE_NUMER' => claimant_info['vaFileNumber']
    )
  end

  # Build nursing home facility fields (Boxes 9-11)
  # @param form [Hash]
  # @return [Hash]
  def build_nursing_home_fields(form)
    nursing_home = form['nursingHomeInformation'] || {}
    address = nursing_home['nursingHomeAddress'] || {}

    {
      'NAME_FACILITY_C' => nursing_home['nursingHomeName'],
      'DATE_ADMISSION_TO_FACILITY_C' => format_date_for_ibm(nursing_home['dateAdmitted'])
    }.merge(build_address_fields(address, 'FACILITY_ADDRESS'))
  end

  # Build Medicaid information fields (Boxes 12-15)
  # @param form [Hash]
  # @return [Hash]
  def build_medicaid_fields(form)
    medicaid = form['medicaidInformation'] || {}

    {
      'MEDICAID_APPROVED_Y' => build_checkbox_value(medicaid['isMedicaidApproved']),
      'MEDICAID_APPROVED_N' => build_checkbox_value(medicaid['isMedicaidApproved'] == false),
      'MEDICAID_APPLIED_Y' => build_checkbox_value(medicaid['hasAppliedForMedicaid']),
      'MEDICAID_APPLIED_N' => build_checkbox_value(medicaid['hasAppliedForMedicaid'] == false),
      'MEDICAID_COVERAGE_Y' => build_checkbox_value(medicaid['isCoveredByMedicaid']),
      'MEDICAID_COVERAGE_N' => build_checkbox_value(medicaid['isCoveredByMedicaid'] == false),
      'MEDICAID_START' => format_date_for_ibm(medicaid['medicaidStartDate']),
      'OUT_OF_POCKET' => format_currency_for_ibm(medicaid['monthlyOutOfPocketAmount'])
    }.compact
  end

  # Build care type fields (Box 16)
  # @param form [Hash]
  # @return [Hash]
  def build_care_type_fields(form)
    care_type = form['careType'] || {}

    {
      'SKILLED_CARE' => build_checkbox_value(care_type == 'skilled'),
      'INTERMEDIATE_CARE' => build_checkbox_value(care_type == 'intermediate')
    }.compact
  end

  # Build nursing home official fields (Boxes 17-21)
  # @param form [Hash]
  # @return [Hash]
  def build_official_fields(form)
    official = form['nursingHomeOfficial'] || {}

    {
      'NAME_COMPLETING_WORKSHEET_C' => official['officialName'],
      'ROLE_PERFORM_AT_FACILITY_C' => official['officialTitle'],
      'FACILITY_TELEPHONE_NUMBER_C' => format_phone_for_ibm(official['officialPhone']),
      'INT_PHONE_NUMBER' => official['internationalPhoneNumber'],
      'SIGNATURE_OF_PROVIDER_C' => official['officialSignature'],
      'SIGNATURE_DATE_PROVIDER_C' => format_date_for_ibm(official['dateSigned'])
    }.compact
  end

  # Build form metadata
  # @return [Hash]
  def build_form_metadata_fields
    build_form_metadata('VA Form 21-0779, SEP 2023')
  end

  # Format currency for IBM (e.g., "1,234.56")
  # @param amount [String, Numeric, nil]
  # @return [String, nil]
  def format_currency_for_ibm(amount)
    return nil unless amount

    # Convert to float if string
    value = amount.is_a?(String) ? amount.to_f : amount
    format('%.2f', value)
  rescue ArgumentError, TypeError
    nil
  end
end
