# frozen_string_literal: true

require 'evss/response'

module EVSS
  module PCIUAddress
    class AddressResponse < EVSS::Response
      attribute :address, EVSS::PCIUAddress::Address
      attribute :control_information, EVSS::PCIUAddress::ControlInformation

      def initialize(status, response = nil)
        attributes = {}
        if response
          attributes[:address] = response.body['cnp_mailing_address']
          attributes[:control_information] = response.body['control_information']
        end
        super(status, attributes)
      end

      def address=(attrs)
        super EVSS::PCIUAddress::Address.build_address(attrs)
      end
    end
  end
end
