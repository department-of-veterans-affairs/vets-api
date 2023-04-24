# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class HigherLevelReviewUploadStatusBatch
    include Sidekiq::Worker

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 30.minutes

    BATCH_SIZE = 100

    def perform
      return unless enabled? && higher_level_review_ids.present?

      Sidekiq::Batch.new.jobs do
        higher_level_review_ids.each_slice(BATCH_SIZE).with_index do |ids, i|
          HigherLevelReviewUploadStatusUpdater.perform_in((i * 5).seconds, ids)
        end
      end
    end

    private

    def higher_level_review_ids
      @higher_level_review_ids ||= HigherLevelReview.v2_or_v0.incomplete_statuses.order(created_at: :asc).pluck(:id)
    end

    def enabled?
      Flipper.enabled? :decision_review_hlr_status_updater_enabled
    end
  end
end
