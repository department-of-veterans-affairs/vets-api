# frozen_string_literal: true

class VeteranFacingFormsRemediationUploader < CarrierWave::Uploader::Base
  include SetAWSConfig

  def size_range
    (1.byte)...(100_000_000.bytes)
  end

  # All the same files allowed by benefits intake, with the
  # addition of json for metadata and csv for manifest
  def extension_allowlist
    %w[bmp csv gif jpeg jpg json pdf png tif tiff txt]
  end

  def initialize(benefits_intake_uuid, directory)
    raise 'The benefits_intake_uuid is missing.' if @benefits_intake_uuid.blank?

    super
    @benefits_intake_uuid = benefits_intake_uuid
    @directory = directory

    set_storage_options!
  end

  def store_dir
    raise 'The s3 directory is missing.' if @directory.blank?

    @directory
  end

  def set_storage_options!
    # TODO: update this to vff specific S3 bucket once it has been created
    s3_settings = Settings.reports.aws
    #  defaults to CarrierWave::Storage::File if not AWS unless a real aws_access_key_id is set
    if s3_settings.aws_access_key_id.present?
      set_aws_config(
        s3_settings.aws_access_key_id,
        s3_settings.aws_secret_access_key,
        s3_settings.region,
        s3_settings.bucket
      )
    end
  end
end
