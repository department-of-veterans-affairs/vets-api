# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class UploadScanner
    include Sidekiq::Job

    # No need to retry since the job is run every 30 seconds
    sidekiq_options retry: false, unique_for: 30.seconds

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
      Rails.logger.info("VBADocuments: Started processing #{upload.class.name.demodulize} from S3",
                        log_details(upload))

      object = bucket.object(upload.guid)
      return false unless object.exists?

      upload.update!(status: 'uploaded')

      Rails.logger.info("VBADocuments: #{upload.class.name.demodulize} progressed to \"uploaded\" status",
                        log_details(upload))

      # Appeals evidence is processed at a later time (after the appeal reaches a "success" status)
      return true if upload.appeals_consumer? && Flipper.enabled?(:decision_review_delay_evidence)

      VBADocuments::UploadProcessor.perform_async(upload.guid, caller: self.class.name)

      Rails.logger.info("VBADocuments: Finished processing #{upload.class.name.demodulize} from S3",
                        log_details(upload))

      true
    end

    def expire(upload)
      upload.update(status: 'expired') if upload.created_at < 20.minutes.ago
    end

    def bucket
      @bucket ||= begin
        s3 = Aws::S3::Resource.new(region: Settings.vba_documents.s3.region,
                                   access_key_id: Settings.vba_documents.s3.aws_access_key_id,
                                   secret_access_key: Settings.vba_documents.s3.aws_secret_access_key)
        s3.bucket(Settings.vba_documents.s3.bucket)
      end
    end

    def log_details(upload)
      { 'job' => self.class.name }.merge(upload.as_json)
    end
  end
end
