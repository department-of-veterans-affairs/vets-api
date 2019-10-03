# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'

module EVSS
  module PPIU
    # Proxy Service for EVSS's PPIU endpoints. For the foreseeable future, EVSS will only support
    # the 'CNP' (Compensation and Pension) payment type and is therefore statically assigned in the
    # request payloads.
    class Service < EVSS::Service
      configuration EVSS::PPIU::Configuration

      # GETs a user's payment information
      #
      # @return [EVSS::PPIU::PaymentInformationResponse] Response with a users payment information
      #
      def get_payment_information
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'paymentInformation', paymentType: 'CNP')
          PaymentInformationResponse.new(raw_response.status, raw_response)
        end
      end

      # POSTs a user's payment information to EVSS and updates their current information
      #
      # @param pay_info [JSON] JSON serialized banking account information
      # @return [EVSS::PPIU::PaymentInformationResponse] Response with a users updated payment information
      #
      def update_payment_information(pay_info)
        body = request_body(pay_info)
        save_req_body(body)

        with_monitoring_and_error_handling do
          raw_response = perform(:post, 'paymentInformation', body, headers)
          PaymentInformationResponse.new(raw_response.status, raw_response)
        end
      end

      private

      def save_req_body(req_body)
        req_body = JSON.parse(req_body)
        req_body['requests'].each do |request|
          request['paymentAccount']['accountNumber'] = '****'
        end

        @sanitized_req_body = req_body
      end

      def handle_error(error)
        if error.is_a?(Common::Client::Errors::ClientError) && error.status != 403 && error.body.is_a?(Hash)
          save_error_details(error)
          raise EVSS::PPIU::ServiceException.new(error.body, @user, @sanitized_req_body)
        else
          super(error)
        end
      end

      def request_body(pay_info)
        pay_info.delete('financial_institution_name') if pay_info['financial_institution_name'].blank?

        {
          'requests' => [
            {
              'paymentType' => 'CNP',
              'paymentAccount' => Hash[
                pay_info.as_json.map { |k, v| [k.camelize(:lower), v] }
              ]
            }
          ]
        }.to_json
      end
    end
  end
end
