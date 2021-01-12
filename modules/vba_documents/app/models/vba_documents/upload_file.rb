# frozen_string_literal: true

module VBADocuments
  class UploadFile < ApplicationRecord
    has_many_attached  :files
    before_save :set_blob_key

    def initialize(attributes = nil)
      super
      assign_guid
    end

    private
    def assign_guid
      self.guid= SecureRandom.uuid
    end

    def set_blob_key
      self.files.each do |file|
        file.blob.key = file.blob.filename.to_s
        puts file.blob.key
      end
    end

  end
end