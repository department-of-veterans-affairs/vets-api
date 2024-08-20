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
        response = decision_review_service.get_higher_level_review(guid).body
        status = response.dig('data', 'attributes', 'status')
        attributes = response.dig('data', 'attributes')

        timestamp = DateTime.now
        params = { metadata: attributes.to_json, metadata_updated_at: timestamp }

        if SUCCESSFUL_STATUS.include? status
          params[:delete_date] = timestamp + RETENTION_PERIOD
          Rails.logger.info("#{self.class.name} updated delete_date", guid:)
        end

        hlr.update(params)
      rescue => e
        Rails.logger.error('DecisionReview::SavedClaimHlrStatusUpdaterJob error', { guid:, message: e.message })
      end

      nil
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
