# frozen_string_literal: true

require_relative 'address_response'
require_relative 'configuration'
require_relative 'countries_response'
require_relative 'states_response'
require 'evss/service'
require 'evss/pciu/request_body'

module EVSS
  module PCIUAddress
    ##
    # Proxy Service for PCIU Address Caseflow.
    #
    # @example Creating a service and fetching a country list
    #   letters_response = EVSS::PCIUAddress::Service.new.get_countries
    #
    class Service < EVSS::Service
      configuration EVSS::PCIUAddress::Configuration

      ##
      # @return [EVSS::PCIUAddress::CountriesResponse] A list of country names
      #
      def get_countries
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'countries')
          EVSS::PCIUAddress::CountriesResponse.new(raw_response.status, raw_response)
        end
      end

      ##
      # @return [EVSS::PCIUAddress::StatesResponse] A list of state names
      #
      def get_states
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'states')
          EVSS::PCIUAddress::StatesResponse.new(raw_response.status, raw_response)
        end
      end

      ##
      # @return [EVSS::PCIUAddress::AddressResponse] Mailing address for a user
      #
      def get_address
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'mailingAddress')
          EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
        end
      end

      ##
      # @return [EVSS::PCIUAddress::AddressResponse] The updated mailing address for a user
      #
      def update_address(address)
        with_monitoring_and_error_handling do
          raw_response = perform(:post, 'mailingAddress', request_body(address), headers)
          EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
        end
      end

      private

      def request_body(address)
        EVSS::PCIU::RequestBody.new(
          address,
          pciu_key: 'cnpMailingAddress',
          date_attr: 'address_effective_date'
        ).set
      end
    end
  end
end
