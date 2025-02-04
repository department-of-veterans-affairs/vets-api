# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require 'evss/service'
require 'evss/ppiu/configuration'
require 'evss/ppiu/payment_information_response'
require 'evss/ppiu/service_exception'

module EVSS
  module PPIU
    # TODO - see if we can remove
    # Proxy Service for EVSS's PPIU endpoints. For the foreseeable future, EVSS will only support
    # the 'CNP' (Compensation and Pension) payment type and is therefore statically assigned in the
    # request payloads.
    class Service < EVSS::Service
      configuration EVSS::PPIU::Configuration

      def initialize(*args)
        super

        raise Common::Exceptions::Unauthorized unless PPIUPolicy.new(@user).access?
      end

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
        save_sanitized_req_body(body)

        with_monitoring_and_error_handling do
          raw_response = perform(:post, 'paymentInformation', body, headers)
          PaymentInformationResponse.new(raw_response.status, raw_response)
        end
      end

      private

      def save_sanitized_req_body(req_body)
        req_body = JSON.parse(req_body)
        req_body['requests'].each do |request|
          request['paymentAccount']['accountNumber'] = '****'
        end

        @sanitized_req_body = req_body
      end

      def handle_error(error)
        if right_error_type?(error) && error.body.is_a?(Hash)
          save_error_details(error)
          raise EVSS::PPIU::ServiceException.new(error.body, @user, @sanitized_req_body)
        else
          super(error)
        end
      end

      def right_error_type?(error)
        (error.is_a?(Common::Client::Errors::ClientError) && error.status != 403) ||
          error.is_a?(EVSS::ErrorMiddleware::EVSSError)
      end

      def request_body(pay_info)
        pay_info.delete('financial_institution_name') if pay_info['financial_institution_name'].blank?

        {
          'requests' => [
            {
              'paymentType' => 'CNP',
              'paymentAccount' =>
                pay_info.as_json.transform_keys { |k| k.camelize(:lower) }

            }
          ]
        }.to_json
      end
    end
  end
end
