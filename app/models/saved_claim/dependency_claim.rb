# frozen_string_literal: true

require 'claims_api/vbms_uploader'

class SavedClaim::DependencyClaim < SavedClaim
  FORM = '686C-674'

  def format_and_upload_pdf(veteran_info)
    parsed_form.merge!(veteran_info)
    form_path = PdfFill::Filler.fill_form(self)

    upload_to_vbms(form_path, veteran_info)
  end

  def valid_vet_info?(veteran_info)
    return false if parsed_form['veteran_contact_information']['veteran_address']
    return false if veteran_info['veteran_information'].blank?
    return false if parsed_form['dependents_application'].blank?

    true
  end

  private

  def upload_to_vbms(path, veteran_info)
    uploader = ClaimsApi::VbmsUploader.new(
      filepath: path,
      file_number: veteran_info['veteran_information']['ssn'],
      doc_type: '148'
    )

    uploader.upload!
  end
end
