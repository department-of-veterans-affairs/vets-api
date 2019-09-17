# frozen_string_literal: true

module ClaimsApi
  class SupportingDocumentUploader < CarrierWave::Uploader::Base
    include SetAwsConfig
    include ValidateFileSize
    include ValidatePdf

    MAX_FILE_SIZE = 25.megabytes

    def initialize(guid)
      super
      @guid = guid

      set_storage_options!
    end

    def store_dir
      raise 'missing guid' if @guid.blank?

      "disability_compensation/#{@guid}"
    end

    def set_storage_options!
      if Settings.evss.s3.uploads_enabled
        set_aws_config(
          Settings.evss.s3.aws_access_key_id,
          Settings.evss.s3.aws_secret_access_key,
          Settings.evss.s3.region,
          Settings.evss.s3.bucket
        )
      else
        self.class.storage = :file
      end
    end
  end
end
