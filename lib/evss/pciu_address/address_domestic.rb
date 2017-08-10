# frozen_string_literal: true

module EVSS
  module PCIUAddress
    class AddressDomestic < Address
      attribute :state_code, String
      attribute :zip_code, String
      attribute :zip_suffix, String
    end
  end
end
