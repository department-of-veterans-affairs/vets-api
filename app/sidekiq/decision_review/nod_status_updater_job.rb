# frozen_string_literal: true

require_relative 'saved_claim_status_updater_job'

module DecisionReview
  class NodStatusUpdaterJob < SavedClaimStatusUpdaterJob
    
    private

    def records_to_update
      @notice_of_disagreements ||= ::SavedClaim::NoticeOfDisagreement.where(delete_date: nil).order(created_at: :asc)
    end

    def statsd_prefix
      'worker.decision_review.saved_claim_nod_status_updater'
    end

    def log_prefix
      'DecisionReview::SavedClaimNodStatusUpdaterJob'
    end

    def get_record_status(guid)
      decision_review_service.get_notice_of_disagreement(guid).body
    end

    def get_evidence_status(guid)
      decision_review_service.get_notice_of_disagreement_upload(guid:).body
    end

    def enabled?
      Flipper.enabled? :decision_review_saved_claim_nod_status_updater_job_enabled
    end
  end
end
