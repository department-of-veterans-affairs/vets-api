# frozen_string_literal: true

# Files that will be associated with a previously submitted claim, from the Claim Status tool
class EVSSClaimDocumentUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  include SetAWSConfig
  include ValidateEVSSFileSize

  def size_range
    1.byte...150.megabytes
  end

  process :fix_file_extension_and_convert_tiff_to_jpg

  def initialize(user_uuid, ids)
    # carrierwave allows only 2 arguments, which they will pass onto
    # different versions by calling the initialize function again,
    # that's why i put all ids in the 2nd argument instead of adding a 3rd argument
    super
    @user_uuid = user_uuid
    @ids = ids
    set_storage_options!
  end

  def store_dir
    store_dir = "evss_claim_documents/#{@user_uuid}"
    @ids.compact.each do |id|
      store_dir += "/#{id}"
    end
    store_dir
  end

  def extension_whitelist
    %w[pdf gif tiff tif jpeg jpg bmp txt]
  end

  def move_to_cache
    false
  end

  private

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

  def fix_file_extension_and_convert_tiff_to_jpg
    file_metadata = file_metadata_from_binary_inspection

    string_to_append_to_filename = if file_metadata&.type == file_metadata_from_filename&.type
                                     nil
                                   else
                                     extension = file_metadata&.extensions&.type
                                     ".#{extension}" if extension
                                   end

    if file_metadata&.type == 'image/tiff'
      convert :jpg
      string_to_append_to_filename = '.jpg'
    end

    define_singleton_method :filename do
      "#{super()}#{string_to_append_to_filename}" if super()
    end
  end

  def file_metadata_from_filename
    MimeMagic.by_path path if path
  end

  def file_metadata_from_binary_inspection
    file_obj = file&.to_file

    MimeMagic.by_magic file_obj if file_obj
  ensure
    file_obj&.close
  end
end
