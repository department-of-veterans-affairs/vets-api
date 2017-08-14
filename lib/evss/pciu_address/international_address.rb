# frozen_string_literal: true

module EVSS
  module PCIUAddress
    class InternationalAddress < Address
      attribute :foreign_code, String
    end
  end
end
