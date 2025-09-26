# frozen_string_literal: true

class HCAAttachmentUploader < CarrierWave::Uploader::Base
  include SetAWSConfig
  include UploaderVirusScan
  include CarrierWave::MiniMagick

  def size_range
    (1.byte)...(10.megabytes)
  end

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

  def extension_allowlist
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
