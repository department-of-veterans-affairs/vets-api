# frozen_string_literal: true

class SupportingDocumentationAttachmentUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  include ValidateFileSize
  include SetAwsConfig

  MAX_FILE_SIZE = 25.megabytes

  def initialize(guid)
    super
    @guid = guid

    set_aws_config(
      Settings.vic.s3.aws_access_key_id,
      Settings.vic.s3.aws_secret_access_key,
      Settings.vic.s3.region,
      Settings.vic.s3.bucket
    ) if Rails.env.production?
  end

  def extension_white_list
    %w[pdf]
  end

  def store_dir
    raise 'missing guid' if @guid.blank?
    "supporting_documentation_attachments/#{@guid}"
  end
end
