# frozen_string_literal: true

class SupportingDocumentationAttachmentUploader < CarrierWave::Uploader::Base
  PROCESSING_CLASS = VIC::ProcessingUploader
  include ValidateFileSize
  include SetAwsConfig
  include AsyncProcessing

  MAX_FILE_SIZE = 25.megabytes

  def initialize(guid)
    super
    @guid = guid

    if Rails.env.production?
      set_aws_config(
        Settings.vic.s3.aws_access_key_id,
        Settings.vic.s3.aws_secret_access_key,
        Settings.vic.s3.region,
        Settings.vic.s3.bucket
      )
    end
  end

  def extension_white_list
    %w[pdf jpg jpeg gif png]
  end

  def store_dir
    raise 'missing guid' if @guid.blank?
    "supporting_documentation_attachments/#{@guid}"
  end
end
