# frozen_string_literal: true

module V0
  class BurialClaimsController < ClaimsBaseController
    def short_name
      'burial_claim'
    end

    def claim_class
      SavedClaim::Burial
    end
  end
end
