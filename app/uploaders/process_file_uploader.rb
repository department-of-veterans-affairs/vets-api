# frozen_string_literal: true

class ProcessFileUploader < CarrierWave::Uploader::Base
  include SetAwsConfig
  include ReencodeImages
  include UploaderVirusScan

  attr_reader(:store_dir)

  def self.get_new_filename(old_filename)
    filename_split = old_filename.split('.')
    "#{filename_split[0]}_processed.#{filename_split[1]}"
  end

  def initialize(store_dir, old_filename = nil)
    super

    @old_filename = old_filename
    @store_dir = store_dir

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

  def filename
    self.class.get_new_filename(@old_filename)
  end
end
