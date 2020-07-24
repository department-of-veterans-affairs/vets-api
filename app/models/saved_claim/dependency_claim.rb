# frozen_string_literal: true

class SavedClaim::DependencyClaim < SavedClaim
  FORM = '686C-674'

  def format_and_upload_pdf(veteran_info)
    parsed_form.merge!(veteran_info)
    form_path = PdfFill::Filler.fill_form(self)
    upload_to_vbms(form_path, veteran_info)
  end

  def upload_to_vbms(path, veteran_info)
    uploader = ClaimsApi::VbmsUploader.new(
      filepath: path,
      file_number: veteran_info['veteran_information']['ssn'],
      doc_type: '148'
    )

    uploader.upload!
  end
end
