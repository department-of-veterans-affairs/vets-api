# frozen_string_literal: true

module EVSS
  module PCIUAddress
    class InternationalAddress < Address
      attribute :city, String
      attribute :country_name, String

      validates :city, pciu_address_line: true, presence: true, length: { maximum: 30 }
      validates :country_name, presence: true
    end
  end
end
