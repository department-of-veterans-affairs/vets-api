# frozen_string_literal: true

# Files that will be associated with a previously submitted claim, from the Claim Status tool
class EVSSClaimDocumentUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  include SetAWSConfig
  include ValidateEVSSFileSize

  def size_range
    1.byte...150.megabytes
  end

  version :converted, if: :tiff_or_incorrect_extension? do
    metadata = file_metadata_from_binary_inspection

    process convert: :jpg, if: :tiff?

    new_ext = if binary_content_does_not_match_file_extension?(metadata)
      file_metadata&.extensions&.first&.then {|ext| ".#{ext}"}
    else
      nil
    end

    def full_filename(file)
      "converted_#{file}#{new_ext}"
    end
  end

  def initialize(user_uuid, ids)
    # carrierwave allows only 2 arguments, which they will pass onto
    # different versions by calling the initialize function again,
    # that's why i put all ids in the 2nd argument instead of adding a 3rd argument
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
    @ids.compact.each do |id|
      store_dir += "/#{id}"
    end
    store_dir
  end

  def extension_allowlist
    %w[pdf gif tiff tif jpeg jpg bmp txt]
  end

  def move_to_cache
    false
  end

  private

  def tiff?(carrier_wave_sanitized_file)
    file_obj = carrier_wave_sanitized_file&.to_file

    file_obj && MimeMagic.by_magic(file_obj)&.type == 'image/tiff'
  ensure
    file_obj&.close
  end

  def binary_content_does_not_match_file_extension?(carrier_wave_sanitized_file)
    file_metadata_from_binary_inspection(carrier_wave_sanitized_file)&.type !=
      file_metadata_from_filename(carrier_wave_sanitized_file)&.type
  end

  def tiff_or_incorrect_extension?
    metadata = file_metadata_from_binary_inspection
    tiff?(metadata) || binary_content_does_not_match_file_extension?(metadata)
  end

  def file_metadata_from_filename(carrier_wave_sanitized_file)
    MimeMagic.by_path carrier_wave_sanitized_file.path if carrier_wave_sanitized_file.path
  end

  def file_metadata_from_binary_inspection(carrier_wave_sanitized_file)
    file = carrier_wave_sanitized_file&.to_file

    MimeMagic.by_magic file if file
  ensure
    file&.close
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
