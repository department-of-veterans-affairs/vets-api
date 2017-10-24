# frozen_string_literal: true

class EVSSClaimDocumentUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  MAX_FILE_SIZE = 25.megabytes

  before :store, :validate_file_size

  version :converted, if: :tiff? do
    process(convert: :jpg)

    def full_filename(file)
      "converted_#{file}.jpg"
    end
  end

  def initialize(user_uuid, tracked_item_id)
    super
    @user_uuid = user_uuid
    @tracked_item_id = tracked_item_id
    set_storage_options!
  end

  def read_for_upload
    if converted.present? && converted.file.exists?
      converted.read
    else
      read
    end
  end

  def store_dir
    store_dir = "evss_claim_documents/#{@user_uuid}"
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

  def tiff?(file)
    file.content_type == 'image/tiff'
  end

  def validate_file_size(file)
    raise CarrierWave::UploadError, 'File size larger than allowed' if file.size > MAX_FILE_SIZE
  end

  def set_storage_options!
    if Settings.evss.s3.uploads_enabled
      self.aws_credentials = {
        access_key_id: Settings.evss.s3.aws_access_key_id,
        secret_access_key: Settings.evss.s3.aws_secret_access_key,
        region: Settings.evss.s3.region
      }
      self.aws_acl = 'private'
      self.aws_bucket = Settings.evss.s3.bucket
      self.aws_attributes = { server_side_encryption: 'AES256' }
      self.class.storage = :aws
    else
      self.class.storage = :file
    end
  end
end
