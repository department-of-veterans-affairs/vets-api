# frozen_string_literal: true
module Preneeds
  class PreneedAttachment < ActiveRecord::Base
    include SetGuid

    attr_encrypted(:file_data, key: Settings.db_encryption_key)

    def set_file_data!(file)
      preneed_attachment_uploader = get_preneed_attachment_uploader
      preneed_attachment_uploader.store!(file)
      self.file_data = { filename: preneed_attachment_uploader.filename }.to_json
    end

    def parsed_file_data
      @parsed_file_data ||= JSON.parse(file_data)
    end

    def get_file
      preneed_attachment_uploader = get_preneed_attachment_uploader
      preneed_attachment_uploader.retrieve_from_store!(parsed_file_data['filename'])
      preneed_attachment_uploader.file
    end

    private

    def get_preneed_attachment_uploader
      PreneedAttachmentUploader.new(guid)
    end
  end
end
