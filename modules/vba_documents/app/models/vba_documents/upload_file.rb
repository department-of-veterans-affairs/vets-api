# frozen_string_literal: true
require_dependency 'vba_documents/multipart_parser'
module VBADocuments
  class UploadFile < ApplicationRecord
    has_many_attached  :files
    before_save :set_blob_key

    def initialize(attributes = nil)
      super
      assign_guid
    end

    # todo have this model only have has_one_attached (always the multipart)
    # have another model use has_many_attached and eat this model with this method as a class method to use for
    # debugging
    def parse_and_upload!
      parsed = self.files.last.open do |file|
        VBADocuments::MultipartParser.parse(file.path)
      end
      self.files.attach(io: parsed['content'], filename: self.guid + '_' + 'content.pdf') #todo change filename to guid
      self.files.attach(io: parsed['attachment1'], filename: self.guid + '_' + 'attachment1.pdf') #todo change filename to guid
      self.files.attach(io: parsed['attachment2'], filename: self.guid + '_' + 'attachment2.pdf') #todo change filename to guid
      save!
    end

    private
    def assign_guid
      self.guid= SecureRandom.uuid
    end

    def set_blob_key
      self.files.each do |file|
        file.blob.key = file.blob.filename.to_s
      end
    end

  end
end

# load('./modules/vba_documents/app/models/vba_documents/upload_file.rb')