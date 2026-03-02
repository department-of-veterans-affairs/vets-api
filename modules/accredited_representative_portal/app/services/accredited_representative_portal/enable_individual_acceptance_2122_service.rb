# frozen_string_literal: true

module AccreditedRepresentativePortal
  class EnableIndividualAcceptance2122Service
    extend Poa2122ServiceHelpers

    def self.call(poa_codes:)
      codes = normalize_codes(poa_codes)
      raise ArgumentError, 'POA codes required' if codes.empty?

      ActiveRecord::Base.transaction do
        orgs = organizations_for(codes)
        reps_updated = set_active_reps_mode!(orgs, 'self_only')

        {
          orgs_updated: 0,
          reps_updated:
        }
      end
    end
  end
end
