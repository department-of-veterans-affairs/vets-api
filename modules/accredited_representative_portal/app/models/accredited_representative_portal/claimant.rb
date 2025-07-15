# frozen_string_literal: true

module AccreditedRepresentativePortal
  class Claimant
    attr_reader :profile, :icn, :poa_requests, :active_poa_codes

    delegate :city, :state, :postal_code, to: :address

    def initialize(profile, poa_requests, active_poa_codes = [])
      @profile = profile
      @icn = profile.icn
      @poa_requests = poa_requests
      @active_poa_codes = active_poa_codes
    end

    def poa_lookup_service
      @poa_lookup_service ||= PoaLookupService.new(icn)
    end

    delegate :claimant_poa_code, to: :poa_lookup_service

    def representative
      poa_lookup_service.representative_name if active_poa_codes.include?(claimant_poa_code)
    end

    def id
      IcnTemporaryIdentifier.save_icn(icn).id
    end

    def first_name
      profile.given_names.first
    end

    def last_name
      profile.family_name
    end

    delegate :address, to: :profile
  end
end
