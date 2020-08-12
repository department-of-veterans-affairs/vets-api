# frozen_string_literal: true

require 'claims_api/vbms_uploader'

class SavedClaim::DependencyClaim < SavedClaim
  FORM = '686C-674'

  validate :validate_686_form_data, on: :run_686_form_jobs

  def upload_pdf
    form_path = PdfFill::Filler.fill_form(self)
    upload_to_vbms(form_path)
  end

  def add_veteran_info(va_file_number_with_payload)
    parsed_form.merge!(va_file_number_with_payload)
  end

  def validate_686_form_data
    if parsed_form['veteran_contact_information']['veteran_address'].blank?
      errors.add(:parsed_form, "Veteran address can't be blank")
    end

    errors.add(:parsed_form, "SSN can't be blank") if parsed_form['veteran_information']['ssn'].blank?
    errors.add(:parsed_form, "Dependent application can't be blank") if parsed_form['dependents_application'].blank?
  end

  private

  def upload_to_vbms(path)
    uploader = ClaimsApi::VbmsUploader.new(
      filepath: path,
      file_number: parsed_form['veteran_information']['ssn'],
      doc_type: '148'
    )

    uploader.upload!
  end
end
