# frozen_string_literal: true

class PreneedAttachmentUploader < CarrierWave::Uploader::Base
  include ValidateFileSize

  MAX_FILE_SIZE = 25.megabytes

  def initialize(guid)
    super
    @guid = guid
    # TODO: setup s3 config
  end

  def extension_white_list
    %w(pdf)
  end

  def store_dir
    raise 'missing guid' if @guid.blank?
    "preneed_attachments/#{@guid}"
  end
end
