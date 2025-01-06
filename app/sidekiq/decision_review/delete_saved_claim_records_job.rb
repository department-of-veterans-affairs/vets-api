# frozen_string_literal: true

require 'sidekiq'

module DecisionReview
  class DeleteSavedClaimRecordsJob
    include Sidekiq::Job

    # No need to retry since the schedule will run this periodically
    sidekiq_options retry: false

    STATSD_KEY_PREFIX = 'worker.decision_review.delete_saved_claim_records'

    def perform
      ActiveSupport::Deprecation.new.warn("#{self.class.name} job is deprecated and will be replaced by DR engine job")

      return unless enabled?

      deleted_records = ::SavedClaim.where(delete_date: ..DateTime.now).destroy_all
      StatsD.increment("#{STATSD_KEY_PREFIX}.count", deleted_records.size)

      nil
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      Rails.logger.error('DecisionReview::DeleteSavedClaimRecordsJob perform exception', e.message)
    end

    private

    def enabled?
      Flipper.enabled? :decision_review_delete_saved_claims_job_enabled
    end
  end
end
