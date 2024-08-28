# frozen_string_literal: true

require 'sidekiq'
require 'decision_review_v1/service'

module DecisionReview
  class SavedClaimScStatusUpdaterJob
    include Sidekiq::Job

    # No need to retry since the schedule will run this every hour
    sidekiq_options retry: false, unique_for: 30.minutes

    RETENTION_PERIOD = 59.days

    SUCCESSFUL_STATUS = %w[complete].freeze

    STATSD_KEY_PREFIX = 'worker.decision_review.saved_claim_sc_status_updater'

    def perform
      return unless enabled? && supplemental_claims.present?

      StatsD.increment("#{STATSD_KEY_PREFIX}.processing_records", supplemental_claims.size)

      supplemental_claims.each do |sc|
        guid = sc.guid
        status, attributes = get_status_and_attributes(guid)

        timestamp = DateTime.now
        params = { metadata: attributes.to_json, metadata_updated_at: timestamp }

        if SUCCESSFUL_STATUS.include? status
          params[:delete_date] = timestamp + RETENTION_PERIOD
          StatsD.increment("#{STATSD_KEY_PREFIX}.delete_date_update")
          Rails.logger.info("#{self.class.name} updated delete_date", guid:)
        else
          StatsD.increment("#{STATSD_KEY_PREFIX}.status", tags: ["status:#{status}"])
        end

        sc.update(params)
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.error")
        Rails.logger.error('DecisionReview::SavedClaimScStatusUpdaterJob error', { guid:, message: e.message })
      end

      nil
    end

    private

    def decision_review_service
      @service ||= DecisionReviewV1::Service.new
    end

    def supplemental_claims
      @supplemental_claims ||= ::SavedClaim::SupplementalClaim.where(delete_date: nil).order(created_at: :asc)
    end

    def get_status_and_attributes(guid)
      response = decision_review_service.get_supplemental_claim(guid).body
      status = response.dig('data', 'attributes', 'status')
      attributes = response.dig('data', 'attributes')

      [status, attributes]
    end

    def enabled?
      Flipper.enabled? :decision_review_saved_claim_sc_status_updater_job_enabled
    end
  end
end
