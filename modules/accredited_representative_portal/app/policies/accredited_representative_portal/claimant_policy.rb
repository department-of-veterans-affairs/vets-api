# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class ClaimantPolicy < ApplicationPolicy
    include ValidatePowerOfAttorney

    def initialize(user, claimant)
      super(user, claimant)
      @claimant_poa_code = claimant&.claimant_poa_code
    end

    def search?
      @user.user_account.active_power_of_attorney_holders.size.positive?
    end

    def claimant_poa_code
      @claimant_poa_code ||= PoaLookupService.new(@record.icn).claimant_poa_code
    end

    def power_of_attorney?
      authorize_poa
    end
  end
end
