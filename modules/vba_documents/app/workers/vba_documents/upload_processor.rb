# frozen_string_literal: true

module VBADocuments
  class UploadProcessor
    include Sidekiq::Worker

    def perform(guid)
      upload = VBADocuments::UploadSubmission.find_by(guid: guid)
      object = bucket.object(upload.guid)
      tempfile = Tempfile.new(upload.guid)
      object.download_file(tempfile.path)
      Rails.logger.info(tempfile.path)
    end

    private

    def bucket
      @bucket ||= begin
        s3 = Aws::S3::Resource.new(region: Settings.documents.s3.region,
                                   access_key_id: Settings.documents.s3.aws_access_key_id,
                                   secret_access_key: Settings.documents.s3.aws_secret_access_key)
        s3.bucket(Settings.documents.s3.bucket)
      end
    end
  end
end
