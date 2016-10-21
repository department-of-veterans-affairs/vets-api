# frozen_string_literal: true

class DisabilityClaimDocumentUploader < CarrierWave::Uploader::Base
  MAX_FILE_SIZE = 25.megabytes

  before :store, :validate_file_size

  def initialize(user_uuid, tracked_item_id)
    super
    @user_uuid = user_uuid
    @tracked_item_id = tracked_item_id
    set_storage_options!
  end

  def store_dir
    "disability_claim_documents/#{@user_uuid}/#{@tracked_item_id}"
  end

  def extension_white_list
    %w(pdf gif tiff tif jpeg jpg bmp txt)
  end

  def move_to_cache
    false
  end

  private

  def validate_file_size(file)
    raise CarrierWave::UploadError, 'File size larger than allowed' if file.size > MAX_FILE_SIZE
  end

  def set_storage_options!
    if ENV['EVSS_S3_UPLOADS'] == 'true'
      self.fog_credentials = {
        provider:              'AWS',
        aws_access_key_id:     ENV['EVSS_AWS_ACCESS_KEY_ID'],
        aws_secret_access_key: ENV['EVSS_AWS_SECRET_ACCESS_KEY'],
        region:                ENV['EVSS_AWS_S3_REGION']
      }
      self.fog_public = false
      self.fog_directory = ENV['EVSS_AWS_S3_BUCKET']
      self.class.storage = :fog
    else
      self.class.storage = :file
    end
  end
end
