# frozen_string_literal: true

require 'common/client/base'

module EVSS
  module PCIU
    class Service < EVSS::Service
      include Common::Client::Monitoring

      configuration EVSS::PCIU::Configuration

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
