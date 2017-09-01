# frozen_string_literal: true

module EVSS
  module PCIUAddress
    class InternationalAddress < Address
      attribute :city, String

      validates :city, pciu_address_line: true, presence: true
      validates :country_name, presence: true
    end
  end
end
