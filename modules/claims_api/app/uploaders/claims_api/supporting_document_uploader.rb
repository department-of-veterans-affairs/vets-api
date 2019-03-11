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

      # if Rails.env.production?
      set_aws_config(
        Settings.claims_api.s3.aws_access_key_id,
        Settings.claims_api.s3.aws_secret_access_key,
        Settings.claims_api.s3.region,
        Settings.claims_api.s3.bucket
      )
      # end
    end

    def store_dir
      raise 'missing guid' if @guid.blank?
      "disability_compensation/#{@guid}"
    end
  end
end
