# frozen_string_literal: true

class SupportingEvidenceAttachmentUploader < CarrierWave::Uploader::Base
  include ValidateFileSize
  include SetAwsConfig
  include ValidatePdf

  MAX_FILE_SIZE = 25.megabytes

  def initialize(guid)
    super
    @guid = guid

    if Rails.env.production?
      set_aws_config(
        Settings.evss.s3.aws_access_key_id,
        Settings.evss.s3.aws_secret_access_key,
        Settings.evss.s3.region,
        Settings.evss.s3.bucket
      )
    end
  end

  def extension_white_list
    %w[pdf png gif tiff tif jpeg jpg bmp txt]
  end

  def store_dir
    raise 'missing guid' if @guid.blank?

    "disability_compensation_supporting_form/#{@guid}"
  end
end
