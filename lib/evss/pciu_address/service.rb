# frozen_string_literal: true
require 'common/client/base'

module EVSS
  module PCIUAddress
    class Service < EVSS::Service
      configuration EVSS::PCIUAddress::Configuration

      def get_countries(user)
        with_error_metrics do
          raw_response = perform(:get, 'countries', nil, headers_for_user(user))
          EVSS::PCIUAddress::CountriesResponse.new(raw_response.status, raw_response)
        end
      end

      def get_states(user)
        with_error_metrics do
          raw_response = perform(:get, 'states', nil, headers_for_user(user))
          EVSS::PCIUAddress::StatesResponse.new(raw_response.status, raw_response)
        end
      end

      def get_address(user)
        with_error_metrics do
          raw_response = perform(:get, 'mailingAddress', nil, headers_for_user(user))
          EVSS::PCIUAddress::AddressResponse.new(raw_response.status, raw_response)
        end
      end

      def update_address(user, address)
        with_error_metrics do
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

      def handle_error(error)
        case error
        when Faraday::ParsingError
          log_message_to_sentry(error.message, :error, extra_context: { url: config.base_path })
          raise_backend_exception('EVSS502', 'PCIUAddress')
        when Common::Client::Errors::ClientError
          raise Common::Exceptions::Forbidden if error.status == 403
          log_message_to_sentry(error.message, :error, extra_context: { url: config.base_path, body: error.body })
          case e.status
          when 400
            raise_backend_exception('EVSS400', 'PCIUAddress', e)
          when 403
            raise Common::Exceptions::Forbidden
          else
            raise_backend_exception('EVSS502', 'PCIUAddress', e)
          end
        else
          raise error
        end
      end
    end
  end
end
