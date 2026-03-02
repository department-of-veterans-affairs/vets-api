# frozen_string_literal: true

module AccreditedRepresentativePortal
  class DisableIndividualAcceptance2122Service
    extend Poa2122ServiceHelpers

    def self.call(poa_codes:)
      codes = normalize_codes(poa_codes)
      raise ArgumentError, 'POA codes required' if codes.empty?

      orgs = organizations_for(codes)

      {
        orgs_updated: 0,
        reps_updated: set_active_reps_mode!(orgs, 'any_request')
      }
    end
  end
end
