# frozen_string_literal: true
require_dependency 'vba_documents/multipart_parser'
module VBADocuments
  class UploadFile < ApplicationRecord
    has_one_attached  :multipart_file
    alias_method :multipart, :multipart_file
    before_save :set_blob_key
    after_save :update_upload_submission

    def initialize(attributes = nil)
      super
      setup
    end

    def upload_submission
      @submission ||= UploadSubmission.find_by_guid(self.guid)
      @submission
    end

    def uploaded?
      uploaded = false
      if(multipart.attached?)
        uploaded = !multipart.blob.id.nil?
      end
      uploaded
    end

    def remove_from_storage
      self.multipart.purge
      upload_submission.update(s3_deleted: true)
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
    def setup
      self.guid= SecureRandom.uuid
      @submission = VBADocuments::UploadSubmission.new
      @submission.guid = guid
    end

    def set_blob_key
      if self.multipart.attached?
        self.multipart.blob.key = self.guid.to_s
      end
    end

    def update_upload_submission
      if (upload_submission.status.eql?('pending') && uploaded?)
        upload_submission.status = 'uploaded'
      end
      upload_submission.save!
    end
  end

end

=begin
 load('./modules/vba_documents/app/models/vba_documents/upload_file.rb')
 load('./modules/vba_documents/app/models/vba_documents/upload_submission.rb')

include VBADocuments
f = UploadFile.new
f.upload_submission

f.multipart.attach(io: StringIO.new("Hello World"), filename: f.guid)
f.multipart.attached?
f.save!

n = UploadFile.new

n.multipart.attach(io: StringIO.new("Hello World"), filename: f.guid)
n.multipart.attached?

=end
