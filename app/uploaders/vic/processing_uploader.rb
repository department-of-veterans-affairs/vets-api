# frozen_string_literal: true

module VIC
  class ProcessingUploader < CarrierWave::Uploader::Base
    include SetAwsConfig
    include ReencodeImages
    include UploaderVirusScan

    attr_reader(:store_dir)
    attr_reader(:filename)

    def initialize(store_dir, filename)
      super

      @store_dir = store_dir
      @filename = filename

      if Rails.env.production?
        set_aws_config(
          Settings.vic.s3.aws_access_key_id,
          Settings.vic.s3.aws_secret_access_key,
          Settings.vic.s3.region,
          Settings.vic.s3.bucket
        )
      end
    end
  end
end
