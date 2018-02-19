# frozen_string_literal: true

class PhotoProcessingUploader < CarrierWave::Uploader::Base
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

      self.aws_acl = 'public-read'
    end
  end
end
