# frozen_string_literal: true
require 'common/client/base'

module EVSS
  module PCIUAddress
    class Service < EVSS::Service
      configuration EVSS::PCIUAddress::Configuration

      def get_countries(user)
        raw_response = perform(:get, 'countries', nil, headers_for_user(user))
        EVSS::PCIUAddress::CountriesResponse.new(raw_response.status, raw_response)
      end

      def get_states(user)
        raw_response = perform(:get, 'states', nil, headers_for_user(user))
        EVSS::PCIUAddress::StatesResponse.new(raw_response.status, raw_response)
      end

      def get_address(user)
        raw_response = perform(:get, 'mailingAddress', nil, headers_for_user(user))
        EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
      end

      def update_address(user, address)
        address_json = {
          'cnpMailingAddress' => address.compact!
        }.to_json
        headers = headers_for_user(user).update('Content-Type' => 'application/json')
        raw_response = perform(:post, 'mailingAddress', address_json, headers)
        EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
      end
    end
  end
end
