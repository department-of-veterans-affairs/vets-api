# frozen_string_literal: true

class VeteranFacingFormsRemediationUploader < CarrierWave::Uploader::Base
  include SetAWSConfig
  include UploaderVirusScan

  class << self
    # TODO: update this to vff specific S3 bucket once it has been created
    # e.g. Settings.vff_simple_forms.s3
    def s3_settings
      Settings.reports.aws
    end

    def new_s3_resource
      Aws::S3::Resource.new(
        region: s3_settings.region,
        access_key_id: s3_settings.aws_access_key_id,
        secret_access_key: s3_settings.aws_secret_access_key
      )
    end

    def get_s3_link(file_path)
      new_s3_resource.bucket(s3_settings.bucket)
                     .object(file_path)
                     .presigned_url(:get, expires_in: 30.minutes.to_i)
    end
  end

  def size_range
    (1.byte)..(100.megabytes)
  end

  # Allowed file types, including those specific to benefits intake
  def extension_allowlist
    %w[bmp csv gif jpeg jpg json pdf png tif tiff txt]
  end

  def initialize(benefits_intake_uuid, directory)
    raise 'The benefits_intake_uuid is missing.' if benefits_intake_uuid.blank?
    raise 'The s3 directory is missing.' if directory.blank?

    @benefits_intake_uuid = benefits_intake_uuid
    @directory = directory

    super()
    set_storage_options!
  end

  def store_dir
    @directory
  end

  private

  def set_storage_options!
    settings = self.class.s3_settings
    if settings.aws_access_key_id.present?
      set_aws_config(
        settings.aws_access_key_id,
        settings.aws_secret_access_key,
        settings.region,
        settings.bucket
      )
    end
  end
end
