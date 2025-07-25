# frozen_string_literal: true

require 'claims_api/vbms_uploader'
require 'pdf_utilities/datestamp_pdf'
require 'dependents/monitor'
require 'dependents/notification_email'

class SavedClaim::DependencyClaim < CentralMailClaim
  FORM = '686C-674'
  STUDENT_ATTENDING_COLLEGE_KEYS = %w[
    student_information
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
    add_disabled_child
  ].freeze

  FORM686 = '21-686c'
  FORM674 = '21-674'
  FORM_COMBO = '686c-674'

  validate :validate_686_form_data, on: :run_686_form_jobs
  validate :address_exists

  attr_accessor :use_v2

  after_initialize do
    self.form_id = if use_v2 || form_id == '686C-674-V2'
                     '686C-674-V2'
                   else
                     self.class::FORM.upcase
                   end
  end

  def pdf_overflow_tracking
    track_each_pdf_overflow(use_v2 ? '686C-674-V2' : '686C-674') if submittable_686?
    track_each_pdf_overflow(use_v2 ? '21-674-V2' : '21-674') if submittable_674?
  rescue => e
    monitor.track_pdf_overflow_tracking_failure(e)
  end

  def track_each_pdf_overflow(subform_id)
    filenames = []
    if subform_id == '21-674-V2'
      parsed_form['dependents_application']['student_information']&.each do |student|
        filenames << to_pdf(form_id: subform_id, student:)
      end
    else
      filenames << to_pdf(form_id: subform_id)
    end
    filenames.each do |filename|
      monitor.track_pdf_overflow(subform_id) if filename.end_with?('_final.pdf')
    end
  ensure
    filenames.each do |filename|
      Common::FileHelpers.delete_file_if_exists(filename)
    end
  end

  def upload_pdf(form_id, doc_type: '148')
    uploaded_forms ||= []
    return if uploaded_forms.include? form_id

    processed_pdfs = []
    if form_id == '21-674-V2'
      parsed_form['dependents_application']['student_information']&.each_with_index do |student, index|
        processed_pdfs << process_pdf(to_pdf(form_id:, student:), created_at, form_id, index)
      end
    else
      processed_pdfs << process_pdf(to_pdf(form_id:), created_at, form_id)
    end
    processed_pdfs.each do |processed_pdf|
      upload_to_vbms(path: processed_pdf, doc_type:)
      uploaded_forms << form_id
      save
    end
  rescue => e
    Rails.logger.debug('DependencyClaim: Issue Uploading to VBMS in upload_pdf method',
                       { saved_claim_id: id, form_id:, error: e })
    raise e
  end

  def process_pdf(pdf_path, timestamp = nil, form_id = nil, iterator = nil)
    processed_pdf = PDFUtilities::DatestampPdf.new(pdf_path).run(
      text: 'Application Submitted on site',
      x: 400,
      y: 675,
      text_only: true, # passing as text only because we override how the date is stamped in this instance
      timestamp:,
      page_number: %w[686C-674 686C-674-V2].include?(form_id) ? 6 : 0,
      template: "lib/pdf_fill/forms/pdfs/#{form_id}.pdf",
      multistamp: true
    )
    renamed_path = iterator.present? ? "tmp/pdfs/#{form_id}_#{id}_#{iterator}_final.pdf" : "tmp/pdfs/#{form_id}_#{id}_final.pdf" # rubocop:disable Layout/LineLength
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
    # check if report674 is present and then check if it's true to avoid hash break.
    parsed_form['view:selectable686_options']&.include?('report674') &&
      parsed_form['view:selectable686_options']['report674']
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
      files = PersistentAttachment.where(guid: supporting_documents.pluck('confirmation_code'))
      files.find_each { |f| f.update(saved_claim_id: id) }
    end
  end

  def document_type
    148
  end

  def upload_to_vbms(path:, doc_type: nil)
    doc_type ||= document_type
    uploader = ClaimsApi::VBMSUploader.new(
      filepath: path,
      file_number: parsed_form['veteran_information']['va_file_number'] || parsed_form['veteran_information']['ssn'],
      doc_type: doc_type.to_s
    )

    uploader.upload! unless Rails.env.development?
  end

  # temporarily commented out before v2 rolls out. will be updated before v2's release.
  # def form_matches_schema
  #   return unless form_is_string
  #
  #   JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[form_id], parsed_form).each do |v|
  #     errors.add(:form, v.to_s)
  #   end
  # end

  def to_pdf(form_id: FORM, student: nil)
    original_form_id = self.form_id
    self.form_id = form_id
    PdfFill::Filler.fill_form(self, nil, { created_at:, student: })
  rescue => e
    monitor.track_to_pdf_failure(e, form_id)
    raise e
  ensure
    self.form_id = original_form_id
  end

  def send_failure_email(email) # rubocop:disable Metrics/MethodLength
    # if the claim is both a 686c and a 674, send a combination email.
    # otherwise, check to see which individual type it is and send the corresponding email.
    personalisation = {
      'first_name' => parsed_form.dig('veteran_information', 'full_name', 'first')&.upcase.presence,
      'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
      'confirmation_number' => confirmation_number
    }
    template_id = if submittable_686? && submittable_674?
                    Settings.vanotify.services.va_gov.template_id.form21_686c_674_action_needed_email
                  elsif submittable_686?
                    Settings.vanotify.services.va_gov.template_id.form21_686c_action_needed_email
                  elsif submittable_674?
                    Settings.vanotify.services.va_gov.template_id.form21_674_action_needed_email
                  else
                    Rails.logger.error('Email template cannot be assigned for SavedClaim', saved_claim_id: id)
                    nil
                  end
    if email.present? && template_id.present?
      if Flipper.enabled?(:dependents_failure_callback_email)
        Dependents::Form686c674FailureEmailJob.perform_async(id, email, template_id, personalisation)
      else
        VANotify::EmailJob.perform_async(
          email,
          template_id,
          personalisation
        )
      end
    end
  end

  ##
  # Determine if claim is a 686, 674, both, or unknown
  #
  def claim_form_type
    return FORM_COMBO if submittable_686? && submittable_674?
    return FORM686 if submittable_686?

    FORM674 if submittable_674?
  rescue => e
    monitor.track_unknown_claim_type(e)
    nil
  end

  ##
  # VANotify job to send Submitted/in-Progress email to veteran
  #
  def send_submitted_email(user = nil)
    type = claim_form_type
    if type == FORM686
      Dependents::NotificationEmail.new(id, user).deliver(:submitted686)
    elsif type == FORM674
      Dependents::NotificationEmail.new(id, user).deliver(:submitted674)
    else
      # Combo or unknown form types use combo email
      Dependents::NotificationEmail.new(id, user).deliver(:submitted686c674)
    end
    monitor.track_send_submitted_email_success(user&.user_account_uuid)
  rescue => e
    monitor.track_send_submitted_email_failure(e, user&.user_account_uuid)
  end

  ##
  # VANotify job to send Received/Confirmation email to veteran
  #
  def send_received_email(user = nil)
    type = claim_form_type
    if type == FORM686
      Dependents::NotificationEmail.new(id, user).deliver(:received686)
    elsif type == FORM674
      Dependents::NotificationEmail.new(id, user).deliver(:received674)
    else
      # Combo or unknown form types use combo email
      Dependents::NotificationEmail.new(id, user).deliver(:received686c674)
    end
    monitor.track_send_received_email_success(user&.user_account_uuid)
  rescue => e
    monitor.track_send_received_email_failure(e, user&.user_account_uuid)
  end

  def monitor
    @monitor ||= Dependents::Monitor.new(id)
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
