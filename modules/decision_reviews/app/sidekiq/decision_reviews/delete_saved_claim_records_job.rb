# frozen_string_literal: true

require 'sidekiq'

module DecisionReviews
  class DeleteSavedClaimRecordsJob
    include Sidekiq::Job

    # No need to retry since the schedule will run this periodically
    sidekiq_options retry: false

    STATSD_KEY_PREFIX = 'worker.decision_review.delete_saved_claim_records'

    def perform
      return unless enabled?

      deleted_saved_claims = delete_saved_claims
      deleted_secondary_forms = secondary_forms_deletion_enabled? ? delete_secondary_appeal_forms : []

      StatsD.increment("#{STATSD_KEY_PREFIX}.count", deleted_saved_claims.size)

      Rails.logger.info('DecisionReviews::DeleteSavedClaimRecordsJob completed successfully',
                        saved_claims_deleted: deleted_saved_claims.size,
                        secondary_forms_deleted: deleted_secondary_forms.size,
                        secondary_forms_deletion_enabled: secondary_forms_deletion_enabled?,
                        total_deleted: deleted_saved_claims.size + deleted_secondary_forms.size)

      nil
    rescue => e
      StatsD.increment("#{STATSD_KEY_PREFIX}.error")
      Rails.logger.error('DecisionReviews::DeleteSavedClaimRecordsJob perform exception', e.message)
    end

    private

    def enabled?
      Flipper.enabled? :decision_review_delete_saved_claims_job_enabled
    end

    def secondary_forms_deletion_enabled?
      Flipper.enabled? :decision_review_delete_secondary_appeal_forms_enabled
    end

    def delete_saved_claims
      ::SavedClaim.where(delete_date: ..DateTime.now).destroy_all
    end

    def delete_secondary_appeal_forms
      SecondaryAppealForm.where(delete_date: ..DateTime.now).destroy_all
    end
  end
end
