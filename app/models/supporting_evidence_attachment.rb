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

  def original_filename
    JSON.parse(file_data)['filename']
  end

  # Obfuscates the attachment's file name for use in mailers, so we don't email PII
  # The intent is the file should still be recognizable to the veteran who uploaded it
  # Follows these rules:
  # - Only masks filenames longer than 5 characters
  # - Masks letters and numbers, but preserves special characters
  # - Includes the file extension
  def obscured_filename
    extension = original_filename[/\.\w*$/]
    filename_without_extension = original_filename.gsub(/\.\w*$/, '')

    if filename_without_extension.length > 5
      obfuscated_portion = filename_without_extension[3..-3].gsub(/[a-zA-Z\d]/, '*')
      filename_without_extension[0..2] + obfuscated_portion + filename_without_extension[-2..] + extension
    else
      original_filename
    end
  end
end
