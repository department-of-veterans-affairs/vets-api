# frozen_string_literal: true

class AttachmentUploader
  MAX_PDF_SIZE_MB = 25

  attr_reader :file, :content_type

  def initialize(file)
    @file = file
  end

  def call
    return { error: 'No file attached', status: :bad_request } if file.nil?

    if valid_file_size?
      { message: 'Attachment has been received', status: :ok }
    else
      { error: 'File size exceeds the allowed limit', status: :unprocessable_entity }
    end
  end

  private

  def valid_file_size?
    file.size <= MAX_PDF_SIZE_MB.megabytes
  end
end
