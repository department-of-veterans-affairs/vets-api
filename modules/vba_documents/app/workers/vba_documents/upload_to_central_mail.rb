# frozen_string_literal: true

require 'sidekiq'

module VBADocuments
  class UploadToCentralMail
    include Sidekiq::Worker

    def perform
      return unless Settings.vba_documents.s3.enabled

      # records = VBADocuments::UploadSubmission.where(status: 'uploaded').order(updated_at: :asc).limit(10) ask BASTOS about this
      VBADocuments::UploadSubmission.where(status: 'uploaded').find_each(order: :asc) do |upload|
        process(upload)
      end
    end

    private

    def process(upload)
      Rails.logger.info('VBADocuments: Processing Uploads to Central Mail: ' + upload.inspect)
      VBADocuments::UploadProcessor.perform_async(upload.guid)
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
