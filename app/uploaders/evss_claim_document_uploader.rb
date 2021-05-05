# frozen_string_literal: true

# Files that will be associated with a previously submitted claim, from the Claim Status tool
class EVSSClaimDocumentUploader < EVSSClaimDocumentUploaderBase
  include CarrierWave::MiniMagick
  include ConvertFileType

  version :converted, if: :tiff_or_incorrect_extension? do
    process(convert: :jpg, if: :tiff?)
    def full_filename(original_name_for_file)
      name = "converted_#{original_name_for_file}"
      extension = CarrierWave::SanitizedFile.new(nil).send(:split_extension, original_name_for_file)[1]
      mimemagic_object = self.class.inspect_binary file
      if self.class.incorrect_extension?(extension: extension, mimemagic_object: mimemagic_object)
        extension = self.class.extensions_from_mimemagic_object(mimemagic_object).first
        return "#{name.gsub('.', '_')}.#{extension}"
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

  def store_dir
    store_dir = "evss_claim_documents/#{@user_uuid}"
    @ids.compact.each do |id|
      store_dir += "/#{id}"
    end
    store_dir
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
end
