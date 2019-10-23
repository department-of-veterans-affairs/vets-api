# frozen_string_literal: true

class PreneedAttachmentUploader < CarrierWave::Uploader::Base
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
      set_aws_config(
        Settings.preneeds.s3.aws_access_key_id,
        Settings.preneeds.s3.aws_secret_access_key,
        Settings.preneeds.s3.region,
        Settings.preneeds.s3.bucket
      )
    end
  end

  def extension_white_list
    %w[pdf jpg jpeg png]
  end

  def store_dir
    raise 'missing guid' if @guid.blank?

    "preneed_attachments/#{@guid}"
  end

  def filename
    super.chomp(File.extname(super)) + '.pdf' if original_filename.present?
  end

  private

  def not_pdf?(file)
    file.content_type != 'application/pdf'
  end
end
