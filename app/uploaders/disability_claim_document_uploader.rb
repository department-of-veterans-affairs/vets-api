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
    store_dir = "disability_claim_documents/#{@user_uuid}"
    store_dir += "/#{@tracked_item_id}" if @tracked_item_id
    store_dir
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
      self.aws_credentials = {
        region: ENV['EVSS_AWS_S3_REGION']
      }
      self.aws_acl = 'private'
      self.aws_bucket = ENV['EVSS_AWS_S3_BUCKET']
      self.aws_attributes = { server_side_encryption: 'AES256' }
      self.class.storage = :aws
    else
      self.class.storage = :file
    end
  end
end
