# frozen_string_literal: true
require 'common/client/base'

module EVSS
  module PCIUAddress
    class Service < EVSS::Service
      configuration EVSS::PCIUAddress::Configuration

      def get_countries(user)
        with_monitoring do
          raw_response = perform(:get, 'countries', nil, headers_for_user(user))
          EVSS::PCIUAddress::CountriesResponse.new(raw_response.status, raw_response)
        end
      end

      def get_states(user)
        with_monitoring do
          raw_response = perform(:get, 'states', nil, headers_for_user(user))
          EVSS::PCIUAddress::StatesResponse.new(raw_response.status, raw_response)
        end
      end

      def get_address(user)
        with_monitoring do
          raw_response = perform(:get, 'mailingAddress', nil, headers_for_user(user))
          EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
        end
      end

      def update_address(user, address)
        with_monitoring do
          address.address_effective_date = DateTime.now.utc
          address = address.as_json.delete_if { |_k, v| v.blank? }
          address_json = {
            'cnpMailingAddress' => Hash[address.map { |k, v| [k.camelize(:lower), v] }]
          }.to_json
          headers = headers_for_user(user).update('Content-Type' => 'application/json')
          raw_response = perform(:post, 'mailingAddress', address_json, headers)
          EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
        end
      end
    end
  end
end
