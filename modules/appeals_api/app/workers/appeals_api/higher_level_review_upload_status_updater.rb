# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class HigherLevelReviewUploadStatusUpdater
    include Sidekiq::Worker

    sidekiq_options 'retry': true, unique_until: :success

    def perform(ids)
      HigherLevelReview.where(id: ids).find_in_batches(batch_size: 100) do |batch|
        HigherLevelReview.refresh_statuses_using_central_mail! batch
      end
    end
  end
end
