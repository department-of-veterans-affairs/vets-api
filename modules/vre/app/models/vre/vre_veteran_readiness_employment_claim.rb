# frozen_string_literal: true

module VRE
  class VREVeteranReadinessEmploymentClaim < ::SavedClaim
    FORM = VRE::Constants::FORM

    # SavedClaims require regional_office to be defined
    def regional_office
      []
    end
  end
end
