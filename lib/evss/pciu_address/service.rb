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

      private

      def with_exception_handling
        yield
      rescue Faraday::ParsingError => e
        log_exception_to_sentry(e, extra_context: { url: config.base_path })
        raise_backend_exception('EVSS502')
      rescue Common::Client::Errors::ClientError => e
        log_message_to_sentry(e.message, :error, extra_context: { url: config.base_path, body: e&.body })
        case e.status
        when 400
          raise_backend_exception('EVSS400', e)
        when 403
          raise Common::Exceptions::Forbidden
        else
          raise_backend_exception('EVSS502', e)
        end
      end

      def raise_backend_exception(key, error = nil)
        raise Common::Exceptions::BackendServiceException.new(
          key,
          { source: 'EVSS::PCIUAddress' },
          error&.status,
          error&.body
        )
      end
    end
  end
end
