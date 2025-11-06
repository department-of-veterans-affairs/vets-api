# frozen_string_literal: true

module VRE
  module Ch31Eligibility
    class EntitlementDetails
      include Vets::Model

      attribute :max_ch31_entitlement, Entitlement
      attribute :ch31_entitlement_remaining, Entitlement
      attribute :entitlement_used, Entitlement
    end
  end
end
