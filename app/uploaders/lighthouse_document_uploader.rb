# frozen_string_literal: true

# Files that will be associated with a previously submitted claim, from the Claim Status tool
class LighthouseDocumentUploader < LighthouseDocumentUploaderBase
  def initialize(icn, ids)
    # carrierwave allows only 2 arguments, which they will pass onto
    # different versions by calling the initialize function again,
    # that's why i put all ids in the 2nd argument instead of adding a 3rd argument
    super
    @icn = icn
    @ids = ids
    set_storage_options!
  end

  def store_dir
    store_dir = "lighthouse_documents/#{@icn}"
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
    if Settings.lighthouse.s3.uploads_enabled
      set_aws_config(
        Settings.lighthouse.s3.aws_access_key_id,
        Settings.lighthouse.s3.aws_secret_access_key,
        Settings.lighthouse.s3.region,
        Settings.lighthouse.s3.bucket
      )
    else
      self.class.storage = :file
    end
  end
end
