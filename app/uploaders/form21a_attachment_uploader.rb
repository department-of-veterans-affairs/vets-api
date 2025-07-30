# frozen_string_literal: true

class Form21aAttachmentUploader < CarrierWave::Uploader::Base
  def store_dir
    # Additional configuration:
    # - Allow only PDF files
    # - Limit size to 25 MB
    # - Use UploaderVirusScan and MiniMagick if needed
    raise 'missing guid' if @guid.blank?

    "form21a_attachments/#{@guid}"
  end
end
