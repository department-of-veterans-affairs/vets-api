# frozen_string_literal: true

require 'common/client/base'
require 'common/exceptions/internal/record_not_found'
require 'common/exceptions/external/gateway_timeout'
require 'common/client/concerns/monitoring'

module EVSS
  module Letters
    class Service < EVSS::Service
      include Common::Client::Monitoring

      configuration EVSS::Letters::Configuration

      INVALID_ADDRESS_ERROR = 'letterDestination.addressLine1.invalid'

      def get_letters
        with_monitoring do
          raw_response = perform(:get, '')
          EVSS::Letters::LettersResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        begin
          log_edipi if invalid_address_error?(e)
        ensure
          handle_error(e)
        end
      end

      def get_letter_beneficiary
        with_monitoring do
          raw_response = perform(:get, 'letterBeneficiary')
          EVSS::Letters::BeneficiaryResponse.new(raw_response.status, raw_response)
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
          raise EVSS::Letters::ServiceException, error.body
        else
          super(error)
        end
      end

      def log_edipi
        InvalidLetterAddressEdipi.find_or_create_by(edipi: @user.edipi)
      end

      def invalid_address_error?(error)
        return false unless error.is_a?(Common::Client::Errors::ClientError)
        error&.body&.dig('messages')&.any? { |m| m['key'].include? INVALID_ADDRESS_ERROR }
      end
    end
  end
end
