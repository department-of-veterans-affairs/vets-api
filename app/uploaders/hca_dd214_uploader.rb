# frozen_string_literal: true

class HcaDd214Uploader < CarrierWave::Uploader::Base
  include ValidateFileSize
  include SetAwsConfig
  include UploaderVirusScan
  include CarrierWave::MiniMagick

  MAX_FILE_SIZE = 25.megabytes

  process(convert: 'pdf', if: :not_pdf?)

  def initialize(guid)
    super
    @guid = guid

    if Rails.env.production?
      # TODO: s3 config
      # set_aws_config(
      #   Settings.preneeds.s3.aws_access_key_id,
      #   Settings.preneeds.s3.aws_secret_access_key,
      #   Settings.preneeds.s3.region,
      #   Settings.preneeds.s3.bucket
      # )
    end
  end

  def extension_white_list
    %w[pdf jpg jpeg png]
  end

  def store_dir
    "dd214_attachments"
  end

  def filename
    @guid
  end

  private

  def not_pdf?(file)
    file.content_type != 'application/pdf'
  end
end
