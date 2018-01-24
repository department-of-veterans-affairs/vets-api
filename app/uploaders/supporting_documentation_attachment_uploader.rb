# frozen_string_literal: true

class SupportingDocumentationAttachmentUploader < CarrierWave::Uploader::Base
  include ValidateFileSize
  include SetAwsConfig

  MAX_FILE_SIZE = 25.megabytes

  def initialize(guid)
    super
    @guid = guid

    # TODO: bucket
    # set_aws_config(
    #   Settings.preneeds.s3.aws_access_key_id,
    #   Settings.preneeds.s3.aws_secret_access_key,
    #   Settings.preneeds.s3.region,
    #   Settings.preneeds.s3.bucket
    # ) if Rails.env.production?
  end

  def extension_white_list
    %w(jpg jpeg gif png pdf)
  end

  def store_dir
    raise 'missing guid' if @guid.blank?
    "supporting_documentation_attachments/#{@guid}"
  end
end
