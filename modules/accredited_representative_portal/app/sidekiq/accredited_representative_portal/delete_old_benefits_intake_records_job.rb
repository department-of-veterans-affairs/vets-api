# frozen_string_literal: true

module AccreditedRepresentativePortal
  class DeleteOldBenefitsIntakeRecordsJob < DeleteOldSavedClaimsJob
    STATSD_KEY_PREFIX = 'worker.accredited_representative_portal.delete_old_benefits_intake_records'

    def statsd_key_prefix
      STATSD_KEY_PREFIX
    end

    private

    def enabled?
      Flipper.enabled?(:accredited_representative_portal_delete_benefits_intake)
    end

    def scope
      AccreditedRepresentativePortal::SavedClaim::BenefitsIntake
    end

    def log_label
      'BenefitsIntake'
    end

    # ----- Rerun helper -----
    def self.rerun_missed!
      new.perform
    end
    private_class_method :rerun_missed!
  end
end
