# frozen_string_literal: true

module AccreditedRepresentativePortal
  class Form21aAttachmentUploader < CarrierWave::Uploader::Base
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
      set_aws_params
    end

    def store_dir
      raise 'missing guid' if @guid.blank?

      "form21a_attachments/#{@guid}"
    end

    def extension_allowlist
      %w[pdf docx]
    end

    def content_type_allowlist
      %w[application/pdf application/vnd.openxmlformats-officedocument.wordprocessingml.document]
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
        upload_start: Time.current
      }

      Rails.logger.info(log)
    end

    def log_transaction_complete(uploaded_file = nil)
      log = {
        process_id: Process.pid,
        filesize: uploaded_file.try(:size),
        upload_complete: Time.current
      }

      Rails.logger.info(log)
    end

    def set_aws_params
      if Settings.ogc.form21a_service_url.s3.uploads_enabled
        self.aws_credentials = {
          region: Settings.ogc.form21a_service_url.s3.region
        }
        self.aws_acl = 'private'
        self.aws_bucket = Settings.ogc.form21a_service_url.s3.bucket
        self.aws_attributes = { server_side_encryption: 'AES256' }
        self.class.storage = :aws
      end
    end
  end
end
