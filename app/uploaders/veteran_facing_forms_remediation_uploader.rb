# frozen_string_literal: true

class VeteranFacingFormsRemediationUploader < CarrierWave::Uploader::Base
  include UploaderVirusScan

  class << self
    def s3_settings
      Settings.vff_simple_forms.aws
    end

    def new_s3_resource
      client = Aws::S3::Client.new(region: s3_settings.region)
      Aws::S3::Resource.new(client:)
    end

    def get_s3_link(file_path)
      new_s3_resource.bucket(s3_settings.bucket)
                     .object(file_path)
                     .presigned_url(:get, expires_in: 30.minutes.to_i)
    end
  end

  def size_range
    (1.byte)...(150.megabytes)
  end

  # Allowed file types, including those specific to benefits intake
  def extension_allowlist
    %w[bmp csv gif jpeg jpg json pdf png tif tiff txt zip]
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

    self.aws_credentials = { region: settings.region }
    self.aws_acl = 'private'
    self.aws_bucket = settings.bucket
    self.aws_attributes = { server_side_encryption: 'AES256' }
    self.class.storage = :aws
  end
end
