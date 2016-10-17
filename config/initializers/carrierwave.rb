# frozen_string_literal: true

# HACK: to use fog meta-gem
# https://github.com/fog/fog/issues/3429
require 'carrierwave/storage/abstract'
require 'carrierwave/storage/file'
require 'carrierwave/storage/fog'

CarrierWave.configure do |config|
  config.fog_credentials = {
    provider:              'AWS',
    aws_access_key_id:     ENV['AWS_ACCESS_KEY_ID'],
    aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
    region:                ENV['AWS_S3_REGION']
  }
  config.fog_directory = ENV['AWS_S3_BUCKET']
  config.fog_public    = false
  config.storage       = ENV['S3_UPLOADS'].try(:downcase) == 'true' ? :fog : :file
end
