# frozen_string_literal: true

require_relative 'saved_claim_status_updater_job'

module DecisionReviews
  class HlrStatusUpdaterJob < SavedClaimStatusUpdaterJob
    private

    def records_to_update
      ::SavedClaim::HigherLevelReview
        .where(delete_date: nil)
        .order(created_at: :asc)
    end

    def statsd_prefix
      'worker.decision_review.saved_claim_hlr_status_updater'
    end

    def log_prefix
      'DecisionReviews::SavedClaimHlrStatusUpdaterJob'
    end

    def service_tag
      'service:higher-level-review'
    end

    def get_record_status(guid)
      decision_review_service.get_higher_level_review(guid).body
    end

    def evidence?
      false
    end

    def secondary_forms?
      false
    end
  end
end
