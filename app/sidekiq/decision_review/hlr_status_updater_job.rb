# frozen_string_literal: true

require_relative 'saved_claim_status_updater_job'

module DecisionReview
  class HlrStatusUpdaterJob < SavedClaimStatusUpdaterJob
    
    private

    def records_to_update
      @higher_level_reviews ||= ::SavedClaim::HigherLevelReview.where(delete_date: nil).order(created_at: :asc)
    end

    def statsd_prefix
      'worker.decision_review.saved_claim_hlr_status_updater'
    end

    def log_prefix
      'DecisionReview::SavedClaimHlrStatusUpdaterJob'
    end

    def get_record_status(guid)
      decision_review_service.get_higher_level_review(guid).body
    end

    def get_evidence_uploads_statuses(_)
      []
    end

    def enabled?
      Flipper.enabled? :decision_review_saved_claim_hlr_status_updater_job_enabled
    end
  end
end
