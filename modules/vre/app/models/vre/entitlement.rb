# frozen_string_literal: true

module VRE
  class Entitlement
    include Vets::Model

    attribute :month, Integer
    attribute :days, Integer
  end
end
