# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class HigherLevelReviewUploadStatusUpdater
    include Sidekiq::Worker

    # Only retry for ~30 minutes since the job that spawns this one runs every hour
    sidekiq_options retry: 5, unique_until: :success

    def perform(ids)
      batch_size = CentralMailUpdater::MAX_UUIDS_PER_REQUEST
      HigherLevelReview.where(id: ids).find_in_batches(batch_size: batch_size) do |batch|
        CentralMailUpdater.new.call(batch)
      end
    end
  end
end
