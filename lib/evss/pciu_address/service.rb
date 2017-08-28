# frozen_string_literal: true
require 'common/client/base'

module EVSS
  module PCIUAddress
    class Service < EVSS::Service
      configuration EVSS::PCIUAddress::Configuration

      def get_countries(user)
        with_exception_handling do
          raw_response = perform(:get, 'countries', nil, headers_for_user(user))
          EVSS::PCIUAddress::CountriesResponse.new(raw_response.status, raw_response)
        end
      end

      def get_states(user)
        with_exception_handling do
          raw_response = perform(:get, 'states', nil, headers_for_user(user))
          EVSS::PCIUAddress::StatesResponse.new(raw_response.status, raw_response)
        end
      end

      def get_address(user)
        with_exception_handling do
          raw_response = perform(:get, 'mailingAddress', nil, headers_for_user(user))
          EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
        end
      end

      def update_address(user, address)
        with_exception_handling do
          address_json = {
            'cnpMailingAddress' => Hash[address.as_json.map { |k, v| [k.camelize(:lower), v] }]
          }.to_json
          headers = headers_for_user(user).update('Content-Type' => 'application/json')
          raw_response = perform(:post, 'mailingAddress', address_json, headers)
          EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
        end
      end

      private

      def with_exception_handling
        yield
      rescue Faraday::ParsingError => e
        log_message_to_sentry(e.message, :error, extra_context: { url: config.base_path })
        raise Common::Exceptions::Forbidden, detail: 'Missing correlation id'
      rescue Common::Client::Errors::ClientError => e
        raise Common::Exceptions::Forbidden if e.status == 403
        log_message_to_sentry(
          e.message, :error, extra_context: { url: config.base_path, body: e.body }
        )
        raise Common::Exceptions::BackendServiceException.new(
          'EVSS502',
          { source: 'EVSS::PCIUAddress' },
          e.status,
          e.body
        )
      end
    end
  end
end
