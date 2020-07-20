# frozen_string_literal: true

class HcaAttachmentUploader < CarrierWave::Uploader::Base
  include ValidateFileSize
  include SetAwsConfig
  include UploaderVirusScan
  include CarrierWave::MiniMagick

  MAX_FILE_SIZE = 10.megabytes

  process(convert: 'jpg', if: :png?)

  def initialize(guid)
    super
    @guid = guid

    if Rails.env.production?
      set_aws_config(
        Settings.hca.s3.aws_access_key_id,
        Settings.hca.s3.aws_secret_access_key,
        Settings.hca.s3.region,
        Settings.hca.s3.bucket
      )
    end
  end

  def extension_white_list
    # accepted by enrollment system: PDF,WORD,JPG,RTF
    %w[pdf doc docx jpg jpeg rtf png]
  end

  def store_dir
    'hca_attachments'
  end

  def filename
    @guid
  end

  private

  def png?(file)
    file.content_type == 'image/png'
  end
end
