# frozen_string_literal: true

require 'claims_api/vbms_uploader'
require 'central_mail/datestamp_pdf'
class SavedClaim::DependencyClaim < CentralMailClaim
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
    report_marriage_of_child_under18
    child_marriage
    report_child18_or_older_is_not_attending_school
    add_spouse
  ].freeze

  validate :validate_686_form_data, on: :run_686_form_jobs
  validate :address_exists

  attr_accessor :formV2

  after_initialize do
    self.form_id = if Flipper.enabled?(:va_dependents_v2)
                     formV2 || form_id == '686C-674V2' ? '686C-674V2' : self.class::FORM.upcase
                   else
                     self.class::FORM.upcase
                   end
  end

  def upload_pdf(form_id, doc_type: '148')
    uploaded_forms ||= []
    return if uploaded_forms.include? form_id

    upload_to_vbms(path: process_pdf(to_pdf(form_id:), created_at, form_id), doc_type:)
    uploaded_forms << form_id
    save
  end

  def process_pdf(pdf_path, timestamp = nil, form_id = nil)
    processed_pdf = CentralMail::DatestampPdf.new(pdf_path).run(
      text: 'Application Submitted on va.gov',
      x: form_id == '686C-674' ? 400 : 300,
      y: form_id == '686C-674' ? 675 : 775,
      text_only: true, # passing as text only because we override how the date is stamped in this instance
      timestamp:,
      page_number: form_id == '686C-674' ? 6 : 0,
      template: "lib/pdf_fill/forms/pdfs/#{form_id}.pdf",
      multistamp: true
    )
    renamed_path = "tmp/pdfs/#{form_id}_#{id}_final.pdf"
    File.rename(processed_pdf, renamed_path) # rename for vbms upload
    renamed_path # return the renamed path
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

  # Run after a claim is saved, this processes any files/supporting documents that are present
  def process_attachments!
    child_documents = parsed_form.dig('dependents_application', 'child_supporting_documents')
    spouse_documents = parsed_form.dig('dependents_application', 'spouse_supporting_documents')
    # add the two arrays together but also account for nil arrays
    supporting_documents = [child_documents, spouse_documents].compact.reduce([], :|)
    if supporting_documents.present?
      files = PersistentAttachment.where(guid: supporting_documents.map { |doc| doc['confirmation_code'] })
      files.find_each { |f| f.update(saved_claim_id: id) }
    end
  end

  def upload_to_vbms(path:, doc_type: '148')
    uploader = ClaimsApi::VBMSUploader.new(
      filepath: path,
      file_number: parsed_form['veteran_information']['va_file_number'] || parsed_form['veteran_information']['ssn'],
      doc_type:
    )

    uploader.upload!
  end

  def to_pdf(form_id: FORM)
    self.form_id = form_id

    PdfFill::Filler.fill_form(self, nil, { created_at: })
  end

  def form_matches_schema
    return unless form_is_string

    JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[form_id], parsed_form).each do |v|
      errors.add(:form, v.to_s)
    end
  end

  private

  def partitioned_686_674_params
    dependent_data = parsed_form

    student_data = dependent_data['dependents_application'].extract!(*STUDENT_ATTENDING_COLLEGE_KEYS)
    veteran_data = dependent_data['dependents_application'].slice('household_income', 'veteran_contact_information')
    college_student_data = { 'dependents_application' => student_data.merge!(veteran_data) }

    { college_student_data:, dependent_data: }
  end
end
