# frozen_string_literal: true

module VBADocuments
  class UploadFile < UploadSubmission
    has_one_attached  :multipart_file
    has_many_attached :parsed_files # see parse_and_upload! below (this field is generally unused).
    alias multipart multipart_file
    before_save :set_blob_key
    after_save :update_upload_submission
    after_find :validate_type

    def initialize(attributes = nil)
      super
      self.use_active_storage = true
    end

    def validate_type
      raise TypeError, "This guid #{guid} can only be instantiated as an UploadSubmission!" unless use_active_storage
    end

    def uploaded?
      uploaded = false
      uploaded = !multipart.blob.id.nil? if multipart.attached?
      uploaded
    end

    def save!(*, **)
      if Settings.vba_documents.instrument
        t1 = Time.zone.now
        super
        t2 = Time.zone.now
        Rails.logger.info("I took #{t2 - t1} seconds for guid #{guid}")
      else
        super
      end
    end

    def remove_from_storage
      multipart.purge
      update(s3_deleted: true)
    end

    # Useful in the rails console during forensic analysis
    # Calling parses and uploads the PDFs / metadata.
    def parse_and_upload!
      parsed = multipart.open do |file|
        VBADocuments::MultipartParser.parse(file.path)
      end
      parsed_files.attach(io: StringIO.new(parsed['metadata'].to_s), filename: "#{guid}_metadata.json")
      pdf_keys = parsed.keys - ['metadata']
      pdf_keys.each do |k|
        parsed_files.attach(io: File.open(parsed[k]), filename: "#{guid}_#{k}.pdf")
      end
      save!
    end

    private

    def set_blob_key
      multipart.blob.key = guid.to_s if multipart.attached?
      if parsed_files.attached?
        parsed_files.each do |file|
          file.blob.key = file.blob.filename.to_s
        end
      end
    end

    def update_upload_submission
      update(status: 'uploaded') if status.eql?('pending') && uploaded?
    end
  end
end
