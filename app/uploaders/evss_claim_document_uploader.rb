# frozen_string_literal: true

# Files that will be associated with a previously submitted claim, from the Claim Status tool
class EVSSClaimDocumentUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  include SetAWSConfig
  include ValidateEVSSFileSize

  class << self
    def tiff?(mimemagic_object:, carrier_wave_sanitized_file:)
      mimemagic_object&.type == 'image/tiff' || carrier_wave_sanitized_file&.content_type == 'image/tiff'
    end

    def incorrect_extension?(mimemagic_object:, carrier_wave_sanitized_file:)
      true_extensions = extensions_from_mimemagic_object(mimemagic_object).map(&:downcase)

      true_extensions.present? && !carrier_wave_sanitized_file.extension.downcase.in?(true_extensions)
    end

    def extensions_from_mimemagic_object(mimemagic_object)
      mimemagic_object&.extensions || []
    end

    def inspect_binary(carrier_wave_sanitized_file)
      file_obj = carrier_wave_sanitized_file&.to_file
      file_obj && MimeMagic.by_magic(file_obj)
    ensure
      file_obj&.close
    end
  end

  def size_range
    1.byte...150.megabytes
  end

  version :converted, if: :tiff_or_incorrect_extension? do
    process(convert: :jpg, if: :tiff?)

    def full_filename(filename)
      name = "converted_#{filename}"

      mimemagic_object = self.class.inspect_binary file
      if self.class.incorrect_extension?(carrier_wave_sanitized_file: file, mimemagic_object: mimemagic_object)
        ext = self.class.extensions_from_mimemagic_object(mimemagic_object).first
        return "#{name}.#{ext}"
      end

      name
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
byebug
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
    self.class.tiff?(
      carrier_wave_sanitized_file: carrier_wave_sanitized_file,
      mimemagic_object: self.class.inspect_binary(carrier_wave_sanitized_file)
    )
  end

  def tiff_or_incorrect_extension?(carrier_wave_sanitized_file)
    args = {
      carrier_wave_sanitized_file: carrier_wave_sanitized_file,
      mimemagic_object: self.class.inspect_binary(carrier_wave_sanitized_file)
    }
    self.class.tiff?(**args) || self.class.incorrect_extension?(**args)
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
