# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class HigherLevelReviewUploadStatusBatch
    include Sidekiq::Worker

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false

    def perform
      return unless enabled? && higher_level_review_ids.present?

      Sidekiq::Batch.new.jobs do
        higher_level_review_ids.each_slice(slice_size) do |ids|
          HigherLevelReviewUploadStatusUpdater.perform_async(ids)
        end
      end
    end

    private

    def higher_level_review_ids
      @higher_level_review_ids ||= HigherLevelReview.received_or_processing.order(created_at: :asc).pluck(:id)
    end

    def slice_size
      (higher_level_review_ids.length / 5.0).ceil
    end

    def enabled?
      Settings.modules_appeals_api.higher_level_review_updater_enabled
    end
  end
end
