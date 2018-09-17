# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'

module EVSS
  module PPIU
    class Service < EVSS::Service
      include Common::Client::Monitoring

      configuration EVSS::PPIU::Configuration

      def get_payment_information
        with_monitoring do
          raw_response = perform(:get, 'paymentInformation', paymentType: 'CNP')
          PaymentInformationResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      private

      def handle_error(error)
        if error.is_a?(Common::Client::Errors::ClientError) && error.status != 403 && error.body.is_a?(Hash)
          log_message_to_sentry(
            error.message, :error, extra_context: { url: config.base_path, body: error.body }
          )
          raise EVSS::PPIU::ServiceException, error.body
        else
          super(error)
        end
      end
    end
  end
end
