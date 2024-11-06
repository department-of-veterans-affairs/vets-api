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

    ERROR_STATUS = 'error'

    STATSD_KEY_PREFIX = 'worker.decision_review.saved_claim_hlr_status_updater'

    def perform
      return unless enabled? && higher_level_reviews.present?

      StatsD.increment("#{STATSD_KEY_PREFIX}.processing_records", higher_level_reviews.size)

      higher_level_reviews.each do |hlr|
        guid = hlr.guid
        status, attributes = get_status_and_attributes(guid)

        timestamp = DateTime.now
        params = { metadata: attributes.to_json, metadata_updated_at: timestamp }

        if SUCCESSFUL_STATUS.include? status
          params[:delete_date] = timestamp + RETENTION_PERIOD
          StatsD.increment("#{STATSD_KEY_PREFIX}.delete_date_update")
          Rails.logger.info("#{self.class.name} updated delete_date", guid:)
        else
          handle_form_status_metrics_and_logging(hlr, status)
        end

        hlr.update(params)
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.error")
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

    def get_status_and_attributes(guid)
      response = decision_review_service.get_higher_level_review(guid).body
      attributes = response.dig('data', 'attributes')
      status = attributes['status']

      [status, attributes]
    end

    def handle_form_status_metrics_and_logging(hlr, status)
      # Skip logging and statsd metrics when there is no status change
      return if JSON.parse(hlr.metadata || '{}')['status'] == status

      if status == ERROR_STATUS
        Rails.logger.info('DecisionReview::SavedClaimHlrStatusUpdaterJob form status error', guid: hlr.guid)
        tags = ['service:higher-level-review', 'function: form submission to Lighthouse']
        StatsD.increment('silent_failure', tags:)
      end

      StatsD.increment("#{STATSD_KEY_PREFIX}.status", tags: ["status:#{status}"])
    end

    def enabled?
      Flipper.enabled? :decision_review_saved_claim_hlr_status_updater_job_enabled
    end
  end
end
