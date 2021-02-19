# frozen_string_literal: true

# Files that will be associated with a previously submitted claim, from the Claim Status tool
class EVSSClaimDocumentUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick
  include SetAWSConfig
  include ValidateEVSSFileSize

  def size_range
    1.byte...150.megabytes
  end

  process :convert_to_jpg, if: :tiff?

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

  class StoreCalledTwiceError < StandardError
    def message
      'EVSSClaimDocumentUploaders are one-time use.'
    end
  end

  def store!(*args, **kwargs, &block)
    raise StoreCalledTwiceError if @this_evss_claim_document_uploader_has_been_used
    @this_evss_claim_document_uploader_has_been_used = true

    return super(*args, &block) unless kwargs.present?

    super(*args, **kwargs, &block)
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

  def convert_to_jpg
    convert :jpg

    define_singleton_method :filename do
      "converted_#{super()}.jpg" if super()
    end
  end
end
