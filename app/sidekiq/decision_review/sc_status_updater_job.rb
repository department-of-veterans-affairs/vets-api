# frozen_string_literal: true

require_relative 'saved_claim_status_updater_job'

module DecisionReview
  class ScStatusUpdaterJob < SavedClaimStatusUpdaterJob
    private

    def records_to_update
      @supplemental_claims ||= ::SavedClaim::SupplementalClaim.where(delete_date: nil).order(created_at: :asc)
    end

    def statsd_prefix
      'worker.decision_review.saved_claim_sc_status_updater'
    end

    def log_prefix
      'DecisionReview::SavedClaimScStatusUpdaterJob'
    end

    def get_record_status(guid)
      decision_review_service.get_supplemental_claim(guid).body
    end

    def get_evidence_status(uuid)
      decision_review_service.get_supplemental_claim_upload(uuid:).body
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

    def enabled?
      Flipper.enabled? :decision_review_saved_claim_sc_status_updater_job_enabled
    end
  end
end
