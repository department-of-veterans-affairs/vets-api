# frozen_string_literal: true

# Files uploaded as part of a form526 submission that will be sent to EVSS upon form submission.
# inherits from ApplicationRecord
class SupportingEvidenceAttachment < FormAttachment
  ATTACHMENT_UPLOADER_CLASS = SupportingEvidenceAttachmentUploader

  # this uploads the file to S3 through its parent class
  # the final filename comes from the uploader once the file is successfully uploaded to S3
  def set_file_data!(file, file_password = nil)
    file_data_json = super
    au = get_attachment_uploader
    if au.converted_exists?
      self.file_data = JSON.parse(file_data_json).merge('converted_filename' => au.final_filename).to_json
    end
    file_data
  end

  def converted_filename
    JSON.parse(file_data)['converted_filename']
  end
end
