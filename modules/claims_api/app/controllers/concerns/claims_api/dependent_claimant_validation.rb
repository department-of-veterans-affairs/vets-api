# frozen_string_literal: true

module ClaimsApi
  module DependentClaimantValidation
    def allow_dependent_claimant?
      return false unless Flipper.enabled?(:lighthouse_claims_api_poa_dependent_claimants)

      claimant = form_attributes['claimant']

      claimant.present? && claimant['relationship']&.downcase != 'self'
    end
  end
end
