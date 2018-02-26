# frozen_string_literal: true

module VIC
  class ProcessingUploader < CarrierWave::Uploader::Base
    include SetAwsConfig
    include ReencodeImages
    include UploaderVirusScan

    attr_reader(:store_dir)

    def self.get_new_filename(old_filename)
      "#{old_filename}.processed"
    end

    def initialize(store_dir, old_filename)
      super

      @store_dir = store_dir
      @old_filename = old_filename

      if Rails.env.production?
        set_aws_config(
          Settings.vic.s3.aws_access_key_id,
          Settings.vic.s3.aws_secret_access_key,
          Settings.vic.s3.region,
          Settings.vic.s3.bucket
        )
      end
    end

    def filename
      self.class.get_new_filename(@old_filename)
    end
  end
end
