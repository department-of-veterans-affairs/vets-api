# frozen_string_literal: true

require 'common/client/base'

module EVSS
  module PCIUAddress
    class Service < EVSS::Service
      include Common::Client::Monitoring

      configuration EVSS::PCIUAddress::Configuration

      def get_address
        with_monitoring do
          raw_response = perform(:get, 'mailingAddress')
          EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def update_address(address)
        with_monitoring do
          address.address_effective_date = DateTime.now.utc
          address = address.as_json.delete_if { |_k, v| v.blank? }
          address_json = {
            'cnpMailingAddress' => Hash[address.map { |k, v| [k.camelize(:lower), v] }]
          }.to_json
          headers = { 'Content-Type' => 'application/json' }
          raw_response = perform(:post, 'mailingAddress', address_json, headers)
          EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
