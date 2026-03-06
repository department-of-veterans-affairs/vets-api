# frozen_string_literal: true

module AccreditedRepresentativePortal
  class DisableOnlineSubmission2122Service
    extend Poa2122ServiceHelpers

    def self.call(poa_codes:)
      codes = normalize_codes(poa_codes)
      raise ArgumentError, 'POA codes required' if codes.empty?

      orgs = organizations_for(codes)

      ActiveRecord::Base.transaction do
        {
          orgs_updated: disable_online_submission!(orgs),
          reps_updated: set_active_reps_mode!(orgs, 'no_acceptance')
        }
      end
    end

    def self.disable_online_submission!(org_scope)
      orgs_to_update = org_scope.where.not(can_accept_digital_poa_requests: false)

      expected = orgs_to_update.count
      updated = orgs_to_update.update_all(can_accept_digital_poa_requests: false) # rubocop:disable Rails/SkipsModelValidations

      if updated != expected
        raise MismatchError,
              "DisableOnlineSubmission2122Service mismatch: expected #{expected} orgs, updated #{updated}"
      end
      updated
    end
    private_class_method :disable_online_submission!
  end
end
