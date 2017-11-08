# frozen_string_literal: true
module Preneeds
  class PreneedAttachment < ActiveRecord::Base
    attr_encrypted(:file_data, key: Settings.db_encryption_key)
    mount_uploader(:file_data, PreneedAttachmentUploader)
  end
end
