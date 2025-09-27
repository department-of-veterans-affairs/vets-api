# frozen_string_literal: true

class HCAAttachmentUploader < CarrierWave::Uploader::Base
  include SetAWSConfig
  include UploaderVirusScan
  include CarrierWave::MiniMagick

  def size_range
    (1.byte)...(10.megabytes)
  end

  process(convert: 'jpg', if: :png?)
  process(convert: 'jpg', if: :heic?)

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

  # accepted by enrollment system: PDF,WORD,JPG,RTF
  def extension_allowlist
    if Flipper.enabled?(:hca_heif_attachments_enabled)
      %w[pdf doc docx jpg jpeg rtf png heic heif]
    else
      %w[pdf doc docx jpg jpeg rtf png]
    end
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

  def heic?(file)
    file.content_type =~ %r{^image/(heic|heif)$}
  end
end
