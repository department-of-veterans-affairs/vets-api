# frozen_string_literal: true

class Form21aAttachmentUploader < CarrierWave::Uploader::Base
  include SetAWSConfig

  include UploaderVirusScan
  include CarrierWave::MiniMagick

  before :store, :log_transaction_start
  after :store, :log_transaction_complete
  def initialize(guid, _unused = nil)
    # carrierwave allows only 2 arguments, which they will pass onto
    # different versions by calling the initialize function again
    # so the _unused argument is necessary

    super
    @guid = guid

    set_aws_config(
      Settings.ogc.form21a_service_url.s3.aws_access_key_id,
      Settings.ogc.form21a_service_url.s3.aws_secret_access_key,
      # Settings.ogc.form21a_service_url.s3.aws_role_arn,
      Settings.ogc.form21a_service_url.s3.region,
      Settings.ogc.form21a_service_url.s3.bucket
    )
  end

  def store_dir
    raise 'missing guid' if @guid.blank?

    "form21a_attachments/#{@guid}"
  end

  def extension_allowlist
    # Only allow PDF
    %w[pdf]
  end

  def filename
    @guid
  end

  def size_range
    (1.byte)...(25.megabytes)
  end

  def log_transaction_start(uploaded_file = nil)
    log = {
      process_id: Process.pid,
      filesize: uploaded_file.try(:size),
      file_headers: uploaded_file.try(:headers),
      upload_start: Time.current
    }

    Rails.logger.info(log)
  end

  def log_transaction_complete(uploaded_file = nil)
    log = {
      process_id: Process.pid,
      filesize: uploaded_file.try(:size),
      file_headers: uploaded_file.try(:headers),
      upload_complete: Time.current
    }

    Rails.logger.info(log)
  end
end
