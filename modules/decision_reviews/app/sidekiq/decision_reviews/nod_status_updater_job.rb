# frozen_string_literal: true

require_relative 'saved_claim_status_updater_job'

module DecisionReviews
  class NodStatusUpdaterJob < SavedClaimStatusUpdaterJob
    private

    def records_to_update
      ::SavedClaim::NoticeOfDisagreement
        .includes(appeal_submission: :appeal_submission_uploads)
        .where(delete_date: nil)
        .order(created_at: :asc)
    end

    def statsd_prefix
      'worker.decision_review.saved_claim_nod_status_updater'
    end

    def log_prefix
      'DecisionReviews::SavedClaimNodStatusUpdaterJob'
    end

    def service_tag
      'service:board-appeal'
    end

    def get_record_status(guid)
      decision_review_service.get_notice_of_disagreement(guid).body
    end

    def get_evidence_status(guid)
      decision_review_service.get_notice_of_disagreement_upload(guid:).body
    end

    def evidence?
      true
    end

    def secondary_forms?
      false
    end
  end
end
