# frozen_string_literal: true
module EVSS
  class FailedClaimsReport
    include Sidekiq::Worker

    def perform
      s3 = Aws::S3::Resource.new(region: Settings.evss.s3.region)
      failed_uploads = []
      sidekiq_retry_timeout = 21.days.ago

      %w(evss disability).each do |type|
        s3.bucket(Settings.evss.s3.bucket).objects(prefix: "#{type}_claim_documents").each do |object|
          if object.last_modified < sidekiq_retry_timeout
            failed_uploads << object.key
          end
        end
      end

      failed_uploads
    end
  end
end
