# frozen_string_literal: true

require 'sidekiq'
require 'decision_review_v1/service'

module DecisionReview
  class SavedClaimHlrStatusUpdaterJob
    include Sidekiq::Job

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 30.minutes

    RETENTION_PERIOD = 59.days

    SUCCESSFUL_STATUS = %w[complete].freeze

    def perform
      return unless enabled? && higher_level_reviews.present?

      higher_level_reviews.each do |hlr|
        guid = hlr.guid
        status = decision_review_service.get_higher_level_review(guid).dig('data', 'attributes', 'status')

        if SUCCESSFUL_STATUS.include? status
          hlr.update(delete_date: DateTime.now + RETENTION_PERIOD)
          Rails.logger.info("#{self.class.name} updated delete_date", guid:)
        end
      end
    end

    private

    def decision_review_service
      @service ||= DecisionReviewV1::Service.new
    end

    def higher_level_reviews
      @higher_level_reviews ||= ::SavedClaim::HigherLevelReview.where(delete_date: nil).order(created_at: :asc)
    end

    def enabled?
      Flipper.enabled? :decision_review_saved_claim_hlr_status_updater_job_enabled
    end
  end
end
