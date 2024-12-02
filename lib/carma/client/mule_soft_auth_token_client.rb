# frozen_string_literal: true

require 'carma/client/mule_soft_auth_token_configuration'

module CARMA
  module Client
    class MuleSoftAuthTokenClient < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = 'api.carma.mulesoft.auth'
      GRANT_TYPE = 'client_credentials'
      SCOPE = 'DTCWriteResource'

      configuration MuleSoftAuthTokenConfiguration

      class GetAuthTokenError < StandardError; end

      def new_bearer_token
        with_monitoring do
          response = perform(:post,
                             auth_token_path,
                             params,
                             token_headers,
                             { timeout: config.timeout })

          return JSON.parse(response.body)['access_token'] if response.status == 200

          raise GetAuthTokenError, "Response: #{response}"
        end
      end

      private

      def params
        URI.encode_www_form({
                              grant_type: GRANT_TYPE,
                              scope: SCOPE
                            })
      end

      def token_headers
        basic_auth = Base64.urlsafe_encode64("#{client_id}:#{client_secret}")

        {
          'Authorization' => "Basic #{basic_auth}",
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      end

      def client_id
        config.settings.client_id
      end

      def client_secret
        config.settings.client_secret
      end

      def auth_token_path
        config.settings.auth_token_path
      end
    end
  end
end
