# frozen_string_literal: true

class EVSSClaimDocumentUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  include ValidateFileSize
  include SetAwsConfig

  MAX_FILE_SIZE = 25.megabytes

  version :converted, if: :tiff? do
    process(convert: :jpg)

    def full_filename(file)
      "converted_#{file}.jpg"
    end
  end

  def initialize(user_uuid, ids)
    # carrierwave allows only 2 arguments, which they will pass onto different versions by calling the initialize function again, that's why i put all ids in the 2nd argument instead of adding a 3rd argument
    super
    @user_uuid = user_uuid
    @ids = ids
    set_storage_options!
  end

  def converted_exists?
    converted.present? && converted.file.exists?
  end

  def final_filename
    if converted_exists?
      converted.file.filename
    else
      filename
    end
  end

  def read_for_upload
    if converted_exists?
      converted.read
    else
      read
    end
  end

  def store_dir
    store_dir = "evss_claim_documents/#{@user_uuid}"
    @ids.each do |id|
      store_dir += "/#{id}" if id
    end
    store_dir
  end

  def extension_white_list
    %w[pdf gif tiff tif jpeg jpg bmp txt]
  end

  def move_to_cache
    false
  end

  private

  def tiff?(file)
    file.content_type == 'image/tiff'
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
