# frozen_string_literal: true

require 'claims_api/vbms_uploader'

class SavedClaim::DependencyClaim < SavedClaim
  FORM = '686C-674'
  STUDENT_ATTENDING_COLLEGE_KEYS = %w[
    student_name_and_ssn
    student_address_marriage_tuition
    last_term_school_information
    school_information
    program_information
    current_term_dates
    student_earnings_from_school_year
    student_networth_information
    student_expected_earnings_next_year
    student_does_have_networth
    student_does_earn_income
    student_will_earn_income_next_year
    student_did_attend_school_last_term
  ].freeze

  DEPENDENT_CLAIM_FLOWS = %w[
    report_death
    report_divorce
    add_child
    report_stepchild_not_in_household
    child_marriage
    not_attending_school
    add_spouse
  ].freeze

  validate :validate_686_form_data, on: :run_686_form_jobs
  validate :address_exists

  def upload_pdf
    form_path = PdfFill::Filler.fill_form(self)
    upload_to_vbms(form_path)
  end

  def add_veteran_info(va_file_number_with_payload)
    parsed_form.merge!(va_file_number_with_payload)
  end

  def formatted_686_data(va_file_number_with_payload)
    partitioned_686_674_params[:dependent_data].merge(va_file_number_with_payload).with_indifferent_access
  end

  def formatted_674_data(va_file_number_with_payload)
    partitioned_686_674_params[:college_student_data].merge(va_file_number_with_payload).with_indifferent_access
  end

  def submittable_686?
    submitted_flows = DEPENDENT_CLAIM_FLOWS.map { |flow| parsed_form['view:selectable686_options'].include?(flow) }

    return true if submitted_flows.include?(true)

    false
  end

  def submittable_674?
    return false if parsed_form['view:selectable686_options']['report674'].blank?

    true
  end

  def address_exists
    if parsed_form.dig('dependents_application', 'veteran_contact_information', 'veteran_address').blank?
      errors.add(:parsed_form, "Veteran address can't be blank")
    end
  end

  def validate_686_form_data
    errors.add(:parsed_form, "SSN can't be blank") if parsed_form['veteran_information']['ssn'].blank?
    errors.add(:parsed_form, "Dependent application can't be blank") if parsed_form['dependents_application'].blank?
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    []
  end

  private

  def partitioned_686_674_params
    dependent_data = parsed_form

    college_student_data = dependent_data['dependents_application'].extract!(*STUDENT_ATTENDING_COLLEGE_KEYS)

    { college_student_data: college_student_data, dependent_data: dependent_data }
  end

  def upload_to_vbms(path)
    uploader = ClaimsApi::VBMSUploader.new(
      filepath: path,
      file_number: parsed_form['veteran_information']['ssn'],
      doc_type: '148'
    )

    uploader.upload!
  end
end
