# frozen_string_literal: true

class SidekiqHpaCronJobs < Common::RedisStore
  def self.clean_up_queues
    999.times.each do |_i|
      SidekiqAlive::CleanupQueues.perform_async
      SidekiqStatsJob.perform_async
      EVSS::DeleteOldClaims.perform_async
      EVSS::DocumentUpload.perform_async
      VBADocuments::UploadStatusBatch.perform_async
      VANotify::InProgressForms.perform_async
      AppealsApi::DailyErrorReport.perform_async
      AppealsApi::HigherLevelReviewUploadStatusBatch.perform_async
    end
  end
end
