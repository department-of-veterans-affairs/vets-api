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
    end

    private

    def process(upload)
      Rails.logger.info('VBADocuments: Processing: ' + upload.inspect)
      object = bucket.object(upload.guid)
      return false unless object.exists?

      # this block is valid while transitioning from GDIT to GCIO
      gdit_pause_date = Time.at(1607720400) # 12/11/2020 4:00:00 pm est this can be anything if we push early
      gcio_start_date = Time.at(1607972400) # 12/14/2020 2:00:00 pm est
      pause_status_update = false

      if upload.created_at > gcio_start_date
        # hr = VBADocuments::UploadSubmission.first.created_at.strftime('%H').to_i
        # VBADocuments::UploadSubmission.first.created_at.in_time_zone("Eastern Time (US & Canada)").strftime('%H').to_i
        hr = upload.created_at.in_time_zone("Eastern Time (US & Canada)").strftime('%H').to_i
        pause_status_update = (hr >= 13 && hr < 15)
      end

      # remove unless statement when GCIO is live on 12/14 or 12/15 deployment
      upload.update(status: 'uploaded') unless pause_status_update

      # remove unless statment with GCIO live deployment
      VBADocuments::UploadProcessor.perform_async(upload.guid) unless Time.now.utc.to_i > gdit_pause_date
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
