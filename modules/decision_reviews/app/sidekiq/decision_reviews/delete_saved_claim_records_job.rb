# frozen_string_literal: true

require 'sidekiq'

module DecisionReviews
  class DeleteSavedClaimRecordsJob
    include Sidekiq::Job

    # No need to retry since the schedule will run this periodically
    sidekiq_options retry: false

    STATSD_KEY_PREFIX = 'worker.decision_review.delete_saved_claim_records'

    def perform
      deleted_records = ::SavedClaim
                        .where(type: [
                                 'SavedClaim::HigherLevelReview',
                                 'SavedClaim::NoticeOfDisagreement',
                                 'SavedClaim::SupplementalClaim'
                               ])
                        .where(delete_date: ..DateTime.now)
                        .destroy_all
      StatsD.increment("#{STATSD_KEY_PREFIX}.count", deleted_records.size)

      nil
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      Rails.logger.error('DecisionReviews::DeleteSavedClaimRecordsJob perform exception', e.message)
    end
  end
end
