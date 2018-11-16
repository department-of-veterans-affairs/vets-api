# frozen_string_literal: true

module EVSS
  module PCIUAddress
    class Service < EVSS::Service
      configuration EVSS::PCIUAddress::Configuration

      def get_countries
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'countries')
          EVSS::PCIUAddress::CountriesResponse.new(raw_response.status, raw_response)
        end
      end

      def get_states
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'states')
          EVSS::PCIUAddress::StatesResponse.new(raw_response.status, raw_response)
        end
      end

      def get_address
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'mailingAddress')
          EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
        end
      end

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
