# frozen_string_literal: true

module AccreditedRepresentativePortal
  class EnableOnlineSubmission2122Service
    extend Poa2122ServiceHelpers

    def self.call(poa_codes:)
      codes = normalize_codes(poa_codes)
      raise ArgumentError, 'POA codes required' if codes.empty?

      orgs = organizations_for(codes)

      ActiveRecord::Base.transaction do
        {
          orgs_updated: enable_online_submission!(orgs),
          reps_updated: set_active_reps_mode!(orgs, 'any_request')
        }
      end
    end

    def self.enable_online_submission!(org_scope)
      orgs_to_update = org_scope.where.not(can_accept_digital_poa_requests: true)

      expected = orgs_to_update.count
      updated = orgs_to_update.update_all(can_accept_digital_poa_requests: true) # rubocop:disable Rails/SkipsModelValidations -- bulk update for performance

      if updated != expected
        raise MismatchError,
              "EnableOnlineSubmission2122Service mismatch: expected #{expected} orgs, updated #{updated}"
      end

      updated
    end
    private_class_method :enable_online_submission!
  end
end
