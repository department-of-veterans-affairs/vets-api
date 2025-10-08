# frozen_string_literal: true

class HCAAttachmentUploader < CarrierWave::Uploader::Base
  include SetAWSConfig
  include UploaderVirusScan
  include CarrierWave::MiniMagick

  def size_range
    (1.byte)...(10.megabytes)
  end

  process :convert_to_jpg, if: :should_convert_to_jpg?

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

  def convert_to_jpg
    file_type = file.content_type
    Rails.logger.info("Attempting to convert #{file_type} file to JPG for GUID: #{@guid}")
    begin
      manipulate! do |img|
        img.format 'jpg'
        img
      end
    rescue MiniMagick::Invalid
      Rails.logger.error("MiniMagick conversion failed for #{file_type} (GUID: #{@guid})")
      raise CarrierWave::ProcessingError, 'Failed to convert file to JPG.'
    end
  end

  def should_convert_to_jpg?(file)
    png?(file) || heic?(file)
  end

  def png?(file)
    file.content_type == 'image/png'
  end

  def heic?(file)
    file.content_type =~ %r{^image/(heic|heif)$}
  end
end
