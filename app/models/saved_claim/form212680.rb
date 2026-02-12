# frozen_string_literal: true

class SavedClaim::Form212680 < SavedClaim
  include IbmDataDictionary

  FORM = '21-2680'

  # Regional office information for Pension Management Center
  def regional_office
    [
      'Department of Veterans Affairs',
      'Pension Management Center',
      'P.O. Box 5365',
      'Janesville, WI 53547-5365'
    ]
  end

  # Business line for VA processing
  def business_line
    'PMC' # Pension Management Center
  end

  # VBMS document type for Aid and Attendance/Housebound
  # Note: This form can be used as either:
  # - Supporting documentation for an existing pension claim (most common)
  # - A primary claim form for A&A/Housebound benefits (some cases)
  def document_type
    540 # Aid and Attendance/Housebound
  end

  # Required metadata format for Lighthouse Benefits Intake API submission
  def metadata_for_benefits_intake
    {
      veteranFirstName: parsed_form.dig('veteranInformation', 'fullName', 'first'),
      veteranLastName: parsed_form.dig('veteranInformation', 'fullName', 'last'),
      fileNumber: parsed_form.dig('veteranInformation', 'vaFileNumber') || parsed_form.dig('veteranInformation', 'ssn'),
      zipCode: parsed_form.dig('claimantInformation', 'address', 'postalCode')&.first(5),
      businessLine: business_line,
      docType: "StructuredData:#{FORM}"
    }
  end

  # Convert form data to IBM GCIO VBA Data Dictionary format
  # Mapping based on Form 21-2680 FEB 2023 Data Dictionary
  def to_ibm
    ibm_data = {}
    ibm_data.merge!(build_veteran_fields)
    ibm_data.merge!(build_claimant_fields_section)
    ibm_data.merge!(build_benefit_information_fields)
    ibm_data.merge!(build_hospitalization_fields)
    ibm_data.merge!(build_signature_fields)
    ibm_data.merge!(build_form_metadata_fields)
    ibm_data
  end

  # Generate pre-filled PDF with veteran sections
  def generate_prefilled_pdf
    pdf_path = to_pdf

    # Update metadata to track PDF generation
    update_metadata_with_pdf_generation

    pdf_path
  end

  # Get PDF download instructions
  def download_instructions
    {
      title: 'Next Steps: Get Physician to Complete Form',
      steps: [
        'Download the pre-filled PDF below',
        'Print the PDF or save it to your device',
        'Take the form to your physician',
        'Have your physician complete Sections VI-VIII',
        'Have your physician sign Section VIII',
        'Scan or photograph the completed form',
        'Upload the completed form at: va.gov/upload-supporting-documents'
      ],
      upload_url: "#{Settings.hostname}/upload-supporting-documents",
      form_number: '21-2680',
      regional_office: regional_office.join(', ')
    }
  end

  # Attachment keys (not used in this workflow, but required by SavedClaim)
  def attachment_keys
    [].freeze
  end

  # Override to_pdf to add veteran signature stamp
  def to_pdf(file_name = nil, fill_options = {})
    pdf_path = PdfFill::Filler.fill_form(self, file_name, fill_options)
    PdfFill::Forms::Va212680.stamp_signature(pdf_path, parsed_form)
  end

  def veteran_first_last_name
    full_name = parsed_form.dig('veteranInformation', 'fullName')
    return 'Veteran' unless full_name.is_a?(Hash)

    "#{full_name['first']} #{full_name['last']}"
  end

  private

  # Build veteran identification fields (Boxes 1-5)
  def build_veteran_fields
    vet_info = parsed_form['veteranInformation'] || {}
    full_name = vet_info['fullName'] || {}

    {
      'VETERAN_FIRST_NAME' => full_name['first'],
      'VETERAN_MIDDLE_INITIAL' => extract_middle_initial(full_name['middle']),
      'VETERAN_LAST_NAME' => full_name['last'],
      'VETERAN_SSN' => vet_info['ssn'],
      'VA_FILE_NUMBER' => vet_info['vaFileNumber'],
      'VETERAN_SERVICE_NUMBER' => vet_info['serviceNumber'],
      'VETERAN_DOB' => format_date_for_ibm(vet_info['dateOfBirth'])
    }
  end

  # rubocop:disable Metrics/MethodLength
  # Build claimant identification and address fields (Boxes 6-12)
  def build_claimant_fields_section
    claimant_info = parsed_form['claimantInformation'] || {}
    full_name = claimant_info['fullName'] || {}
    address = claimant_info['address'] || {}

    fields = {
      'CLAIMANT_FIRST_NAME' => full_name['first'],
      'CLAIMANT_MIDDLE_INITIAL' => extract_middle_initial(full_name['middle']),
      'CLAIMANT_LAST_NAME' => full_name['last'],
      'CLAIMANT_SSN' => claimant_info['ssn'],
      'CLAIMANT_DOB' => format_date_for_ibm(claimant_info['dateOfBirth']),
      'PHONE_NUMBER' => claimant_info['phoneNumber'] || claimant_info['internationalPhoneNumber'],
      'EMAIL' => claimant_info['email']
    }

    # Add relationship checkboxes (Box 8)
    relationship = claimant_info['relationship']&.downcase
    fields['SELF'] = build_checkbox_value(relationship == 'self')
    fields['SPOUSE'] = build_checkbox_value(relationship == 'spouse')
    fields['PARENT'] = build_checkbox_value(relationship == 'parent')
    fields['CHILD'] = build_checkbox_value(relationship == 'child')

    # Add address fields (Box 10)
    fields['CLAIMANT_ADDRESS_LINE1'] = address['street']
    fields['CLAIMANT_ADDRESS_LINE2'] = address['street2']
    fields['CLAIMANT_ADDRESS_CITY'] = address['city']
    fields['CLAIMANT_ADDRESS_STATE'] = address['state']
    fields['CLAIMANT_ADDRESS_COUNTRY'] = address['country']
    fields['CLAIMANT_ADDRESS_ZIP5'] = address['postalCode']&.first(5)

    fields
  end
  # rubocop:enable Metrics/MethodLength

  # Build benefit information fields (Box 13)
  def build_benefit_information_fields
    benefit_selection = parsed_form.dig('benefitInformation', 'benefitSelection')&.downcase

    {
      'CB_SMC' => build_checkbox_value(benefit_selection == 'smc'),
      'CB_SMP' => build_checkbox_value(benefit_selection == 'smp')
    }
  end

  # Build hospitalization fields (Box 14)
  def build_hospitalization_fields
    additional_info = parsed_form['additionalInformation'] || {}
    is_hospitalized = additional_info['currentlyHospitalized']
    hospital_address = additional_info['hospitalAddress'] || {}

    {
      'CL_HOSPITALIZED_YES' => build_checkbox_value(is_hospitalized == true),
      'CL_HOSPITALIZED_NO' => build_checkbox_value(is_hospitalized == false),
      'ADMISSION_DATE' => format_date_for_ibm(additional_info['admissionDate']),
      'HOSPITAL_NAME' => additional_info['hospitalName'],
      'HOSPITAL_ADDRESS' => format_hospital_address(hospital_address)
    }
  end

  # Build signature fields (Box 15)
  def build_signature_fields
    signature_info = parsed_form['veteranSignature'] || {}

    {
      'CLAIMANT_SIGNATURE' => signature_info['signature'],
      'CLAIMANT_SIGNATURE_DATE' => format_date_for_ibm(signature_info['date']),
      'VETERAN_SSN_1' => parsed_form.dig('veteranInformation', 'ssn'),
      'VETERAN_SSN_2' => parsed_form.dig('veteranInformation', 'ssn'),
      'VETERAN_SSN_3' => parsed_form.dig('veteranInformation', 'ssn')
    }
  end

  # Build form metadata fields
  def build_form_metadata_fields
    {
      'FORM_TYPE' => FORM,
      'FORM_TYPE_1' => FORM,
      'FORM_TYPE_2' => FORM,
      'FORM_TYPE_3' => FORM
    }
  end

  # Format hospital address for single field
  def format_hospital_address(address)
    return nil unless address

    parts = [
      address['street'],
      address['street2'],
      address['city'],
      address['state'],
      address['postalCode'],
      address['country']
    ].compact.reject(&:empty?)

    parts.join(', ').presence
  end

  def update_metadata_with_pdf_generation
    current_metadata = metadata.present? ? JSON.parse(metadata) : {}
    current_metadata['pdf_generated_at'] = Time.current.iso8601
    current_metadata['submission_method'] = 'print_and_upload'

    self.metadata = current_metadata.to_json
    save!(validate: false)
  end
end
