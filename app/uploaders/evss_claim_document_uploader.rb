# frozen_string_literal: true

# Files that will be associated with a previously submitted claim, from the Claim Status tool
class EVSSClaimDocumentUploader < EVSSClaimDocumentUploaderBase
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
    if Settings.claims_api.evss.s3.uploads_enabled
      set_aws_config(
        Settings.claims_api.evss.s3.aws_access_key_id,
        Settings.claims_api.evss.s3.aws_secret_access_key,
        Settings.claims_api.evss.s3.region,
        Settings.claims_api.evss.s3.bucket
      )
    else
      self.class.storage = :file
    end
  end
end
