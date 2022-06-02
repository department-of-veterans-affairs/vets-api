# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class HigherLevelReviewUploadStatusBatch
    include Sidekiq::Worker

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false

    # Throttling works by grabbing a majority of the oldest records, but also some of the newest.
    # This way more recent records won't appear to "stall out" while we play catch-up.
    THROTTLED_OLDEST_LIMIT = 40
    THROTTLED_NEWEST_LIMIT = 10

    BATCH_SIZE = 100

    def perform
      return unless enabled? && higher_level_review_ids.present?

      Sidekiq::Batch.new.jobs do
        higher_level_review_ids.each_slice(BATCH_SIZE) do |ids|
          HigherLevelReviewUploadStatusUpdater.perform_async(ids)
        end
      end
    end

    private

    def higher_level_review_ids
      relation = HigherLevelReview.v2.incomplete_statuses

      # TODO: Remove this conditional after we turn on throttling in Flipper on all envs
      if Settings.vsp_environment.present?
        @higher_level_review_ids ||= throttled_ids(relation)
        return @higher_level_review_ids
      end

      @higher_level_review_ids ||= if Flipper.enabled?(:decision_review_hlr_status_update_throttling)
                                     throttled_ids relation
                                   else
                                     unthrottled_ids relation
                                   end
    end

    def unthrottled_ids(relation)
      relation.order(created_at: :asc).pluck(:id)
    end

    def throttled_ids(relation)
      ids = relation.order(created_at: :asc).limit(THROTTLED_OLDEST_LIMIT).pluck(:id)
      if ids.size < THROTTLED_OLDEST_LIMIT
        Rails.logger.warn('AppealsApi::HigherLevelReviewUploadStatusBatch::ThrottleWarning',
                          'throttle_limit' => THROTTLED_OLDEST_LIMIT,
                          'actual_count' => ids.size)
        return ids
      end

      ids += relation.order(created_at: :desc).limit(THROTTLED_NEWEST_LIMIT).pluck(:id)
      ids.uniq
    end

    def enabled?
      Settings.modules_appeals_api.higher_level_review_updater_enabled
    end
  end
end
