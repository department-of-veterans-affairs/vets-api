# frozen_string_literal: true

module SOB
  module DGI
    class Entitlement
      include Vets::Model

      attribute :months, Integer
      attribute :days, Integer
    end
  end
end
