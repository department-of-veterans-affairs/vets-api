# frozen_string_literal: true

class SupportingDocumentationAttachmentUploader < CarrierWave::Uploader::Base
  PROCESSING_CLASS = VIC::ProcessingUploader
  include SetAWSConfig
  include AsyncProcessing
  include LogMetrics

  def size_range
    1.byte...25.megabytes
  end

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

  def extension_whitelist
    %w[pdf jpg jpeg gif png tif tiff]
  end

  def store_dir
    raise 'missing guid' if @guid.blank?

    "supporting_documentation_attachments/#{@guid}"
  end
end
