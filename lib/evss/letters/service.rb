# frozen_string_literal: true
require 'common/client/base'
require 'common/exceptions/internal/record_not_found'
require 'common/exceptions/external/gateway_timeout'

module EVSS
  module Letters
    class Service < EVSS::Service
      configuration EVSS::Letters::Configuration

      def get_letters
        with_monitoring do
          raw_response = perform(:get, '')
          EVSS::Letters::LettersResponse.new(raw_response.status, raw_response)
        end
      end

      def get_letter_beneficiary
        with_monitoring do
          raw_response = perform(:get, 'letterBeneficiary')
          EVSS::Letters::BeneficiaryResponse.new(raw_response.status, raw_response)
        end
      end

      private

      def handle_error(error)
        if error.is_a?(Common::Client::Errors::ClientError) && error.status != 403 && error.body.is_a?(Hash)
          log_message_to_sentry(
            error.message, :error, extra_context: { url: config.base_path, body: error.body }
          )
          raise EVSS::Letters::ServiceException, error.body
        else
          super(error)
        end
      end
    end
  end
end
