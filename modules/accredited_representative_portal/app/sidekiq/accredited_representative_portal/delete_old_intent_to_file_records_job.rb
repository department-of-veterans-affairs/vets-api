# frozen_string_literal: true

module AccreditedRepresentativePortal
  class DeleteOldIntentToFileRecordsJob < DeleteOldSavedClaimsJob
    STATSD_KEY_PREFIX = 'worker.accredited_representative_portal.delete_old_intent_to_file_records'

    def statsd_key_prefix
      STATSD_KEY_PREFIX
    end

    private

    def enabled?
      Flipper.enabled?(:accredited_representative_portal_delete_benefits_intake)
    end

    def scope
      AccreditedRepresentativePortal::SavedClaim::BenefitsClaims::IntentToFile
    end

    def log_label
      'IntentToFile'
    end

    # ----- Rerun helper -----
    def self.rerun_missed!
      new.perform
    end
    private_class_method :rerun_missed!
  end
end
