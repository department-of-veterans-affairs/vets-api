# frozen_string_literal: true

# Files uploaded as part of a form526 submission that will be sent to EVSS upon form submission.
# inherits from ApplicationRecord
class SupportingEvidenceAttachment < FormAttachment
  ATTACHMENT_UPLOADER_CLASS = SupportingEvidenceAttachmentUploader
  FILENAME_EXTENSION_MATCHER = /\.\w*$/
  OBFUSCATED_CHARACTER_MATCHER = /[a-zA-Z\d]/
  MAX_FILENAME_LENGTH = 100

  # this uploads the file to S3 through its parent class
  # the final filename comes from the uploader once the file is successfully uploaded to S3
  def set_file_data!(file, file_password = nil)
    file_data_json = super
    parsed_data = JSON.parse(file_data_json)
    au = get_attachment_uploader
    
    # Shorten the original filename if it's too long
    parsed_data['filename'] = shorten_filename(parsed_data['filename']) if parsed_data['filename']
    
    # Shorten converted filename if it exists
    if au.converted_exists?
      original_filename = au.final_filename
      parsed_data['converted_filename'] = shorten_filename(original_filename)
    end
    
    self.file_data = parsed_data.to_json
    file_data
  end

  def converted_filename
    parsed_file_data['converted_filename']
  end

  def original_filename
    parsed_file_data['filename']
  end

  # Obfuscates the attachment's file name for use in mailers, so we don't email PII
  # The intent is the file should still be recognizable to the veteran who uploaded it
  # Follows these rules:
  # - Only masks filenames longer than 5 characters
  # - Masks letters and numbers, but preserves special characters
  # - Includes the file extension
  def obscured_filename
    extension = original_filename[FILENAME_EXTENSION_MATCHER]
    filename_without_extension = original_filename.gsub(FILENAME_EXTENSION_MATCHER, '')

    if filename_without_extension.length > 5
      # Obfuscate with the letter 'X'; we cannot obfuscate with special characters such as an asterisk,
      # as these filenames appear in VA Notify Mailers and their templating engine uses markdown.
      # Therefore, special characters can be interpreted as markdown and introduce formatting issues in the mailer
      obfuscated_portion = filename_without_extension[3..-3].gsub(OBFUSCATED_CHARACTER_MATCHER, 'X')
      filename_without_extension[0..2] + obfuscated_portion + filename_without_extension[-2..] + extension
    else
      original_filename
    end
  end

  private

  def shorten_filename(filename)
    return filename if filename.length <= MAX_FILENAME_LENGTH

    # Preserve file extension while shortening
    extension = File.extname(filename)
    name_without_ext = File.basename(filename, extension)
    max_name_length = MAX_FILENAME_LENGTH - extension.length
    shortened_name = name_without_ext[0, max_name_length]
    shortened_name + extension
  end
end
