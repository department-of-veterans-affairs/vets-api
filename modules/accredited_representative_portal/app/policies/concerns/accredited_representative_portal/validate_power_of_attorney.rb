# frozen_string_literal: true

module AccreditedRepresentativePortal
  module ValidatePowerOfAttorney
    extend ActiveSupport::Concern

    def authorize_poa
      return false unless @user
      return false if claimant_poa_code.blank?

      representative_poa_codes.include? claimant_poa_code
    end

    def claimant_poa_code
      @claimant_poa_code ||= PoaLookupService.new(@record).claimant_poa_code
    end

    def representative_poa_codes
      @user.user_account.active_power_of_attorney_holders.map(&:poa_code)
    end
  end
end
