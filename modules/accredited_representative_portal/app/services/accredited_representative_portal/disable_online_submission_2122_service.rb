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

      updated = 0
      orgs_to_update.find_each do |vso|
        vso.update!(can_accept_digital_poa_requests: false)
        updated += 1
      end

      updated
    end
    private_class_method :disable_online_submission!
  end
end
