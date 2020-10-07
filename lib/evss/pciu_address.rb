# frozen_string_literal: true

require_relative 'pciu_address/address'
require_relative 'pciu_address/military_address'
require_relative 'pciu_address/international_address'
require_relative 'pciu_address/domestic_address'

module EVSS
  module PCIUAddress
    def self.build_address(attrs)
      case attrs['type']
      when Address::ADDRESS_TYPES[:domestic]
        EVSS::PCIUAddress::DomesticAddress.new(attrs)
      when Address::ADDRESS_TYPES[:international]
        EVSS::PCIUAddress::InternationalAddress.new(attrs)
      when Address::ADDRESS_TYPES[:military]
        EVSS::PCIUAddress::MilitaryAddress.new(attrs)
      else
        raise ArgumentError, "Unsupported address type: #{attrs['type']}"
      end
    end
  end
end
