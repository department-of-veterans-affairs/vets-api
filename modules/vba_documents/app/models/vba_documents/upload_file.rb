# frozen_string_literal: true
require_dependency 'vba_documents/multipart_parser'
module VBADocuments
  class UploadFile < UploadSubmission
    has_one_attached  :multipart_file
    has_many_attached :parsed_files #see parse_and_upload! below (this field is generally unused).
    alias_method :multipart, :multipart_file
    before_save :set_blob_key
    after_save :update_upload_submission
    after_find :validate_type

    def initialize(attributes = nil)
      super
      self.use_active_storage = true
    end

    def validate_type
      if !self.use_active_storage
        raise TypeError.new("This guid #{self.guid} can only be instantiated as an UploadSubmission!")
      end
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
      self.update(s3_deleted: true)
    end

    # Useful in the rails console during forensic analysis
    # Calling parses and uploads the PDFs / metadata.
    def parse_and_upload!
      parsed = self.multipart.open do |file|
        VBADocuments::MultipartParser.parse(file.path)
      end
      self.parsed_files.attach(io: StringIO.new(parsed['metadata'].to_s), filename: self.guid + '_' + "metadata.json")
      pdf_keys = parsed.keys - ['metadata']
      pdf_keys.each do |k|
        self.parsed_files.attach(io: File.open(parsed[k]), filename: self.guid + '_' + "#{k}.pdf")
      end
      save!
      puts "Your files have been uploaded!"
      puts "Don't forget to cleanup when done by running:"
      puts "UploadFile.find_by_guid(\'#{self.guid}\').parsed_files.purge"
    end

    private

    def set_blob_key
      if self.multipart.attached?
        self.multipart.blob.key = self.guid.to_s
      end
      if self.parsed_files.attached?
        self.parsed_files.each do |file|
          file.blob.key = file.blob.filename.to_s
        end
      end
    end

    def update_upload_submission
      if (self.status.eql?('pending') && uploaded?)
        self.update(status: 'uploaded')
      end
    end
  end

end

=begin
 load('./modules/vba_documents/app/models/vba_documents/upload_file.rb')
 load('./modules/vba_documents/app/models/vba_documents/upload_submission.rb')

include VBADocuments
f = UploadFile.new

f.multipart.attach(io: StringIO.new("Hello World\n"), filename: f.guid)
f.multipart.attached?
f.save!

n = UploadFile.new

n.multipart.attach(io: StringIO.new("Hello World\n"), filename: f.guid)
n.multipart.attached?
      parsed = uf.multipart.open do |file|
        VBADocuments::MultipartParser.parse(file.path)
      end
=end
