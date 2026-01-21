# frozen_string_literal: true

require_relative 'saved_claim_status_updater_job'

module DecisionReviews
  class ScStatusUpdaterJob < SavedClaimStatusUpdaterJob
    private

    def records_to_update
      ::SavedClaim::SupplementalClaim
        .includes(appeal_submission: %i[appeal_submission_uploads secondary_appeal_forms])
        .where(delete_date: nil)
        .order(created_at: :asc)
    end

    def statsd_prefix
      'worker.decision_review.saved_claim_sc_status_updater'
    end

    def log_prefix
      'DecisionReviews::SavedClaimScStatusUpdaterJob'
    end

    def service_tag
      'service:supplemental-claims'
    end

    def get_record_status(guid)
      decision_review_service.get_supplemental_claim(guid).body
    end

    def get_evidence_status(guid)
      decision_review_service.get_supplemental_claim_upload(guid:).body
    end

    def evidence?
      true
    end

    def secondary_forms?
      true
    end

    def benefits_intake_service
      @intake_service ||= BenefitsIntake::Service.new
    end
  end
end
