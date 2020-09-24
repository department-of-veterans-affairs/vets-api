# frozen_string_literal: true

module V0
  class PensionClaimsController < ClaimsBaseController
    def short_name
      'pension_claim'
    end

    def claim_class
      SavedClaim::Pension
    end
  end
end
