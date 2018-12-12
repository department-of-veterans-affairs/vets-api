# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'

module EVSS
  module PPIU
    class Service < EVSS::Service
      configuration EVSS::PPIU::Configuration

      def get_payment_information
        with_monitoring_and_error_handling do
          raw_response = perform(:get, 'paymentInformation', paymentType: 'CNP')
          PaymentInformationResponse.new(raw_response.status, raw_response)
        end
      end

      private

      def handle_error(error)
        if error.is_a?(Common::Client::Errors::ClientError) && error.status != 403 && error.body.is_a?(Hash)
          save_error_details(error)
          raise EVSS::PPIU::ServiceException, error.body
        else
          super(error)
        end
      end
    end
  end
end
