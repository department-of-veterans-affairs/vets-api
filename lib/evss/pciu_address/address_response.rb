# frozen_string_literal: true
require 'evss/response'

module EVSS
  module PCIUAddress
    class AddressResponse < EVSS::Response
      attribute :address, EVSS::PCIUAddress::Address
      attribute :control_information, EVSS::PCIUAddress::ControlInformation

<<<<<<< a82d49d5c11d13297594a627c76024caf9d045d6
      ADDRESS_TYPES = {
        domestic: 'DOMESTIC',
        international: 'INTERNATIONAL',
        military: 'MILITARY'
      }.freeze

=======
>>>>>>> adding pciu address controller
      def initialize(status, response = nil)
        attributes = {}
        if response
          attributes[:address] = response.body['cnp_mailing_address']
          attributes[:control_information] = response.body['control_information']
        end
        super(status, attributes)
      end
<<<<<<< a82d49d5c11d13297594a627c76024caf9d045d6

      def address=(attrs)
        case attrs['type']
        when ADDRESS_TYPES[:domestic]
          super EVSS::PCIUAddress::AddressDomestic.new(attrs)
        when ADDRESS_TYPES[:international]
          super EVSS::PCIUAddress::AddressInternational.new(attrs)
        when ADDRESS_TYPES[:military]
          super EVSS::PCIUAddress::AddressMilitary.new(attrs)
        else
          raise ArgumentError, "Unsupported address type: #{attrs['type']}"
        end
      end
=======
>>>>>>> adding pciu address controller
    end
  end
end
