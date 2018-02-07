# frozen_string_literal: true

class ProfilePhotoAttachmentUploader < CarrierWave::Uploader::Base
  include ValidateFileSize
  include SetAwsConfig

  MAX_FILE_SIZE = 10.megabytes

  def initialize(guid, in_progress_form)
    @guid = guid
    @in_progress_form = in_progress_form

    super(@guid)

    if Rails.env.production?
      set_aws_config(
        Settings.vic.s3.aws_access_key_id,
        Settings.vic.s3.aws_secret_access_key,
        Settings.vic.s3.region,
        Settings.vic.s3.bucket
      )

      self.aws_acl = 'public-read'
    end
  end

  def extension_white_list
    %w[jpg jpeg gif png]
  end

  def filename
    @guid
  end

  def store_dir
    dir = @in_progress_form&.id || 'anonymous'
    "profile_photo_attachments/#{dir}"
  end
end
