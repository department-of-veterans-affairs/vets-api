# frozen_string_literal: true

require 'evss/response'
require 'evss/pciu_address'
require 'evss/pciu_address/control_information'

module EVSS
  module PCIUAddress
    ##
    # Model for PCIU address response
    #
    # @param status [Integer] The HTTP status code
    # @param response [Hash] The API response
    #
    # @!attribute address
    #   @return [EVSS::PCIUAddress] The address data returned by the service
    # @!attribute control_information
    #   @return[EVSS::PCIUAddress::ControlInformation]
    #
    class AddressResponse < EVSS::Response
      attribute :address, EVSS::PCIUAddress
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
        @address = EVSS::PCIUAddress.build_address(attrs)
      end
    end
  end
end
