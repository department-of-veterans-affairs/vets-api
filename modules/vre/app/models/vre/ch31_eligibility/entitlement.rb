# frozen_string_literal: true

module VRE
  module Ch31Eligibility
    class Entitlement
      include Vets::Model

      attribute :month, Integer
      attribute :days, Integer
    end
  end
end
