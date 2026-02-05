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

  def update_metadata_with_pdf_generation
    current_metadata = metadata.present? ? JSON.parse(metadata) : {}
    current_metadata['pdf_generated_at'] = Time.current.iso8601
    current_metadata['submission_method'] = 'print_and_upload'

    self.metadata = current_metadata.to_json
    save!(validate: false)
  end

  # Convert form data to IBM MMS VBA Data Dictionary format
  # @return [Hash] VBA Data Dictionary payload for form 21-2680
  # Reference: FEB2023-Table 1.csv
  def to_ibm
    build_ibm_payload(parsed_form)
  end

  # Build the IBM data dictionary payload from the parsed claim form
  # @param form [Hash]
  # @return [Hash]
  def build_ibm_payload(form)
    build_veteran_fields(form)
      .merge(build_claimant_info_fields(form))
      .merge(build_claim_type_fields(form))
      .merge(build_hospitalization_fields(form))
      .merge(build_claimant_signature_fields(form))
      .merge(build_examination_fields(form))
      .merge(build_physical_assessment_fields(form))
      .merge(build_disability_fields(form))
      .merge(build_daily_activities_fields(form))
      .merge(build_vision_fields(form))
      .merge(build_nursing_home_assessment_fields(form))
      .merge(build_mental_capacity_fields(form))
      .merge(build_physical_restrictions_fields(form))
      .merge(build_mobility_fields(form))
      .merge(build_examiner_fields(form))
      .merge(build_form_metadata_fields(form))
  end

  # Build veteran identification fields (Boxes 1-5)
  # @param form [Hash]
  # @return [Hash]
  def build_veteran_fields(form)
    vet_info = form['veteranInformation'] || {}

    build_veteran_basic_fields(vet_info).merge(
      'VETERAN_SERVICE_NUMBER' => vet_info['veteranServiceNumber']
    )
  end

  # Build claimant information fields (Boxes 6-12)
  # @param form [Hash]
  # @return [Hash]
  def build_claimant_info_fields(form)
    claimant_info = form['claimantInformation'] || {}
    claimant_addr = claimant_info['address'] || {}

    build_claimant_fields(claimant_info).merge(
      build_relationship_fields(claimant_info['relationship']),
      build_address_fields(claimant_addr, 'CLAIMANT_ADDRESS'),
      'PHONE_NUMBER' => format_phone_for_ibm(claimant_info['phoneNumber']),
      'EMAIL' => claimant_info['email']
    )
  end

  # Build relationship checkboxes (Box 8)
  # @param relationship [String, nil]
  # @return [Hash]
  def build_relationship_fields(relationship)
    {
      'SELF' => build_checkbox_value(relationship == 'self'),
      'SPOUSE' => build_checkbox_value(relationship == 'spouse'),
      'PARENT' => build_checkbox_value(relationship == 'parent'),
      'CHILD' => build_checkbox_value(relationship == 'child')
    }.compact
  end

  # Build claim type fields (Box 13)
  # @param form [Hash]
  # @return [Hash]
  def build_claim_type_fields(form)
    claim_type = form['claimType'] || {}

    {
      'CB_SMC' => build_checkbox_value(claim_type == 'specialMonthlyCompensation'),
      'CB_SMP' => build_checkbox_value(claim_type == 'specialMonthlyPension')
    }.compact
  end

  # Build hospitalization fields (Box 14)
  # @param form [Hash]
  # @return [Hash]
  def build_hospitalization_fields(form)
    hospital = form['hospitalizationInformation'] || {}

    {
      'CL_HOSPITALIZED_YES' => build_checkbox_value(hospital['isHospitalized']),
      'CL_HOSPITALIZED_NO' => build_checkbox_value(hospital['isHospitalized'] == false),
      'ADMISSION_DATE' => format_date_for_ibm(hospital['admissionDate']),
      'HOSPITAL_NAME' => hospital['hospitalName'],
      'HOSPITAL_ADDRESS' => hospital['hospitalAddress']
    }.compact
  end

  # Build claimant signature fields (Box 15)
  # @param form [Hash]
  # @return [Hash]
  def build_claimant_signature_fields(form)
    signature = form['claimantSignature'] || {}

    {
      'CLAIMANT_SIGNATURE' => signature['signature'],
      'CLAIMANT_SIGNATURE_DATE' => format_date_for_ibm(signature['dateSigned'])
    }.compact
  end

  # Build examination fields (Boxes 16-18)
  # @param form [Hash]
  # @return [Hash]
  def build_examination_fields(form)
    exam = form['examinationInformation'] || {}
    disabilities = exam['permanentDisabilities'] || []

    {
      'EXAM_DATE' => format_date_for_ibm(exam['examinationDate']),
      'COMPLETE_DIAGNOSIS' => exam['completeDiagnosis'],
      'CURRENT_DISABILITY1' => disabilities[0],
      'CURRENT_DISABILITY2' => disabilities[1],
      'CURRENT_DISABILITY3' => disabilities[2],
      'CURRENT_DISABILITY4' => disabilities[3],
      'CURRENT_DISABILITY5' => disabilities[4],
      'CURRENT_DISABILITY6' => disabilities[5]
    }.compact
  end

  # Build physical assessment fields (Boxes 19-24)
  # @param form [Hash]
  # @return [Hash]
  def build_physical_assessment_fields(form)
    physical = form['physicalAssessment'] || {}

    {
      'CLAIMANT_AGE' => physical['age'],
      'CL_WEIGHT_ACTUAL' => physical['weightActual'],
      'CL_WEIGHT_ESTIMATED' => physical['weightEstimated'],
      'CL_HEIGHT_FEET' => physical['heightFeet'],
      'CL_HEIGHT_INCHES' => physical['heightInches'],
      'CL_NUTRITION' => physical['nutrition'],
      'CL_GAIT' => physical['gait'],
      'CL_BLOOD_PRESSURE' => physical['bloodPressure'],
      'CL_PULSE_RATE' => physical['pulseRate'],
      'CL_RESPIRATORY_RATE' => physical['respiratoryRate']
    }.compact
  end

  # Build disability restriction fields (Box 25)
  # @param form [Hash]
  # @return [Hash]
  def build_disability_fields(form)
    {
      'CL_RSTRCTD_DSBLT' => form.dig('disabilityRestrictions', 'description')
    }.compact
  end

  # Build daily activities assistance fields (Boxes 26-27)
  # @param form [Hash]
  # @return [Hash]
  def build_daily_activities_fields(form)
    activities = form['dailyActivities'] || {}
    bed_confinement = activities['bedConfinement'] || {}

    {
      'CL_CONFINED_BED_9P_A' => bed_confinement['hours9pmTo9am'],
      'CL_CONFINED_BED_9A_P' => bed_confinement['hours9amTo9pm'],
      'CL_BATHE_YES' => build_checkbox_value(activities['requiresAssistance']&.include?('bathing')),
      'CLAIMANT_FEED_SELF_NO' => build_checkbox_value(activities['requiresAssistance']&.include?('eating')),
      'CL_CLOTHE_SELF_YES' => build_checkbox_value(activities['requiresAssistance']&.include?('dressing')),
      'CL_AMBULATE_YES' => build_checkbox_value(activities['requiresAssistance']&.include?('ambulating')),
      'CL_HYGIENE_YES' => build_checkbox_value(activities['requiresAssistance']&.include?('hygiene')),
      'CL_SELF_TRNSFR_YES' => build_checkbox_value(activities['requiresAssistance']&.include?('transferring')),
      'CL_TOILET_YES' => build_checkbox_value(activities['requiresAssistance']&.include?('toileting')),
      'CL_MDCTN_MGMT_YES' => build_checkbox_value(activities['requiresAssistance']&.include?('medication')),
      'ADDTL_ACTVTS' => build_checkbox_value(activities['additionalActivities'].present?),
      'ADDTL_ACTVTS_EXPLAIN' => activities['additionalActivities']
    }.compact
  end

  # Build vision fields (Box 28)
  # @param form [Hash]
  # @return [Hash]
  def build_vision_fields(form)
    vision = form['visionAssessment'] || {}

    {
      'CL_LEGALLY_BLIND_EXP' => vision['legallyBlindExplanation'],
      'CL_LEGALLY_BLIND_YES' => build_checkbox_value(vision['isLegallyBlind']),
      'CL_LEGALLY_BLIND_NO' => build_checkbox_value(vision['isLegallyBlind'] == false),
      'LEFT_EYE_CRRCTNS' => vision['leftEyeCorrectedVision'],
      'RIGHT_EYE_CRRCTNS' => vision['rightEyeCorrectedVision']
    }.compact
  end

  # Build nursing home care assessment (Box 29)
  # @param form [Hash]
  # @return [Hash]
  def build_nursing_home_assessment_fields(form)
    nursing_home = form['nursingHomeCareAssessment'] || {}

    {
      'CL_NRSNG_HM_CR_EXP' => nursing_home['explanation'],
      'CL_NRSNG_HM_CR_YES' => build_checkbox_value(nursing_home['requiresNursingHomeCare']),
      'CL_NRSNG_HM_CR_NO' => build_checkbox_value(nursing_home['requiresNursingHomeCare'] == false)
    }.compact
  end

  # Build mental capacity assessment (Box 30)
  # @param form [Hash]
  # @return [Hash]
  def build_mental_capacity_fields(form)
    mental_capacity = form['mentalCapacityAssessment'] || {}

    {
      'CL_MNG_BNFT_PMNTS_EXP' => mental_capacity['explanation'],
      'CL_MNG_BNFT_PMNTS_YES' => build_checkbox_value(mental_capacity['canManageBenefitPayments']),
      'CL_MNG_BNFT_PMNTS_NO' => build_checkbox_value(mental_capacity['canManageBenefitPayments'] == false)
    }.compact
  end

  # Build physical restrictions fields (Boxes 31-34)
  # @param form [Hash]
  # @return [Hash]
  def build_physical_restrictions_fields(form)
    restrictions = form['physicalRestrictions'] || {}

    {
      'CL_PSTR_APPRNC' => restrictions['postureAndAppearance'],
      'CL_UPR_XTRMTY_RSTRCNS' => restrictions['upperExtremityRestrictions'],
      'CL_LWR_XTRMTY_RSTRCNS' => restrictions['lowerExtremityRestrictions'],
      'CL_SPN_NK_TRNK_RSTRCNS' => restrictions['spineTrunkNeckRestrictions'],
      'CL_FRTHR_RSTRCNS_HBTS' => restrictions['furtherRestrictionsAndHabits'],
      'CL_RTN_CRCMSTNCS_TRVL' => restrictions['routineCircumstancesTravel']
    }.compact
  end

  # Build mobility and aids fields (Box 37)
  # @param form [Hash]
  # @return [Hash]
  def build_mobility_fields(form)
    mobility = form['mobilityAssessment'] || {}

    {
      'MVMNT_AIDS_RQRD_YES' => build_checkbox_value(mobility['requiresMovementAids']),
      'MVMNT_AIDS_RQRD_NO' => build_checkbox_value(mobility['requiresMovementAids'] == false),
      'CL_ND_AID_AFTR_1_BLCK' => build_checkbox_value(mobility['requiresAidAfter'] == '1block'),
      'CL_ND_AID_AFTR_5_6_BLCK' => build_checkbox_value(mobility['requiresAidAfter'] == '5or6blocks'),
      'CL_ND_AID_AFTR_1_MIL' => build_checkbox_value(mobility['requiresAidAfter'] == '1mile'),
      'CL_ND_AID_AFTR_OTHR' => mobility['requiresAidAfterOther']
    }.compact
  end

  # Build examiner information fields (Boxes 38-45)
  # @param form [Hash]
  # @return [Hash]
  def build_examiner_fields(form)
    examiner = form['examinerInformation'] || {}
    facility = examiner['medicalFacility'] || {}

    {
      'EXAMINER_NAME' => examiner['examinerName'],
      'EXAMINER_TITLE' => examiner['examinerTitle'],
      'EXAMINER_SIGNATURE' => examiner['examinerSignature'],
      'DATE_SIGNED' => format_date_for_ibm(examiner['dateSigned']),
      'NPI_NUMBER' => examiner['npiNumber'],
      'MDCL_FCLT_NM' => facility['facilityName'],
      'EXAMINER_ADDRESS' => facility['facilityAddress'],
      'EXAMINER_PHONE_NUMBER' => format_phone_for_ibm(facility['facilityPhoneNumber'])
    }.compact
  end

  # Build form metadata fields
  # @param form [Hash]
  # @return [Hash]
  def build_form_metadata_fields(form)
    vet_info = form['veteranInformation'] || {}

    build_form_metadata('2680', {
                          'VETERAN_SSN_1' => vet_info['ssn'],
                          'VETERAN_SSN_2' => vet_info['ssn'],
                          'VETERAN_SSN_3' => vet_info['ssn']
                        })
  end
end
