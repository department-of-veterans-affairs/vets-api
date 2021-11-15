# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class UploadScanner
    include Sidekiq::Worker

    def perform
      return unless Settings.vba_documents.s3.enabled

      VBADocuments::UploadSubmission.where(status: 'pending').find_each do |upload|
        processed = process(upload)
        expire(upload) unless processed
      end
    rescue => e
      Rails.logger.error("Error in upload scanner #{e.message}", e)
    end

    private

    def process(upload)
      Rails.logger.info("VBADocuments: Processing: #{upload.inspect}")
      object = bucket.object(upload.guid)
      return false unless object.exists?

      upload.update(status: 'uploaded')
      VBADocuments::UploadProcessor.perform_async(upload.guid, caller: self.class.name)
      true
    end

    def expire(upload)
      upload.update(status: 'expired') if upload.created_at < Time.zone.now - 20.minutes
    end

    def bucket
      @bucket ||= begin
        s3 = Aws::S3::Resource.new(region: Settings.vba_documents.s3.region,
                                   access_key_id: Settings.vba_documents.s3.aws_access_key_id,
                                   secret_access_key: Settings.vba_documents.s3.aws_secret_access_key)
        s3.bucket(Settings.vba_documents.s3.bucket)
      end
    end
  end
end
# def again
# load('./modules/vba_documents/app/workers/vba_documents/upload_processor.rb')
# load('./modules/vba_documents/app/workers/vba_documents/upload_scanner.rb')
# g = "0f35783e-4b33-4e22-b64f-9a50eb391b49"
#
# u = UploadSubmission.find_by_guid(@g)
# u.status = 'pending'
# u.save
# UploadScanner.new.perform
# end
