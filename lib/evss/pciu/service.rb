# frozen_string_literal: true

require 'common/client/base'

module EVSS
  module PCIU
    # EVSS::PCIU endpoints for a user's mailing address, email address,
    # primary/secondary phone numbers, and countries
    #
    # @param [User] Initialized with a user through the EVSS::Service parent
    #
    class Service < EVSS::Service
      include Common::Client::Monitoring

      configuration EVSS::PCIU::Configuration

      # Returns a response object containing the user's email address and
      # its effective date
      #
      # @return [EVSS::PCIU::EmailAddressResponse] Sample response.email_address:
      #   {
      #     "effective_date" => "2012-04-03T04:00:00.000+0000",
      #     "value" => "test2@test1.net"
      #   }
      #
      def get_email_address
        with_monitoring do
          raw_response = perform(:get, 'emailAddress')

          EVSS::PCIU::EmailAddressResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end
    end
  end
end
