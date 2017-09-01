# frozen_string_literal: true

module EVSS
  module PCIUAddress
    class DomesticAddress < Address
      attribute :city, String
      attribute :state_code, String
      attribute :zip_code, String
      attribute :zip_suffix, String

      validates :city, pciu_address_line: true, presence: true
      validates :state_code, presence: true
      validates :country_name, presence: true
      validates :zip_code, presence: true
    end
  end
end
