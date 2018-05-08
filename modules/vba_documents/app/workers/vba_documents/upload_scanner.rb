# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class UploadScanner
    include Sidekiq::Worker

    def perform
      return unless Settings.vba_documents.s3.enabled
      VBADocuments::UploadSubmission.where(status: 'pending').find_each do |upload|
        # TODO: expire records after upload URL is obsolete (default 900 secs)
        processed = process(upload)
        expire(upload) unless processed
      end
    end

    private

    def process(upload)
      Rails.logger.info('VBADocuments: Processing: ' + upload.inspect)
      return false unless bucket.object(upload.guid).exists?
      VBADocuments::UploadProcessor.perform_async(upload.guid)
      upload.update(status: 'uploaded')
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
