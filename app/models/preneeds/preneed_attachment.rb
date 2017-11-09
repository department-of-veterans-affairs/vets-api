# frozen_string_literal: true
module Preneeds
  class PreneedAttachment < ActiveRecord::Base
    attr_encrypted(:file_data, key: Settings.db_encryption_key)

    after_initialize do
      # TODO make this a module
      self.guid ||= SecureRandom.uuid
    end

    def set_file_data(file)
      preneed_attachment_uploader = PreneedAttachmentUploader.new(guid)
      preneed_attachment_uploader.store!(file)
      self.file_data = { filename: preneed_attachment_uploader.filename }.to_json
    end
  end
end
