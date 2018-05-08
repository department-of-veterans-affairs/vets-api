#frozen_string_literal: true

class AncillaryFormAttachmentUploader < CarrierWave::Uploader::Base
  include ValidateFileSize
  include SetAwsConfig

  MAX_FILE_SIZE = 25.megabytes

  def initialize(guid)
    super
    @guid = guid

    if Rails.env.production?
      set_aws_config(
        Settings.disability_compensation_form.s3.aws_access_key_id,
        Settings.disability_compensation_form.s3.aws_secret_access_key,
        Settings.disability_compensation_form.s3.region,
        Settings.disability_compensation_form.s3.bucket,
      )
    end
  end

  def extension_white_list
    %w[pdf png gif tiff tif jpeg jpg bmp txt]
  end

  def store_dir
    raise 'missing guid' if @guid.blank?
    "disability_compensation_form/#{@guid}"
  end
end
