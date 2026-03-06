# frozen_string_literal: true

require 'common/client/base'
require 'time_of_need/mule_soft/configuration'

module TimeOfNeed
  module MuleSoft
    ##
    # Auth token client for MuleSoft OAuth2 client credentials flow
    #
    # Fetches a bearer token using client_id and client_secret.
    # Modeled after CARMA::Client::MuleSoftAuthTokenClient.
    #
    class AuthTokenClient < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = 'api.time_of_need.mulesoft.auth'
      GRANT_TYPE = 'client_credentials'

      configuration TimeOfNeed::MuleSoft::AuthTokenConfiguration

      class GetAuthTokenError < StandardError; end

      ##
      # Fetches a new bearer token from the MuleSoft auth endpoint
      #
      # @return [String] the bearer token
      # @raise [GetAuthTokenError] if token retrieval fails
      def new_bearer_token
        with_monitoring do
          response = perform(:post,
                             auth_token_path,
                             params,
                             token_headers)

          return JSON.parse(response.body)['access_token'] if response.status == 200

          raise GetAuthTokenError, "Response: #{response}"
        end
      end

      private

      def params
        URI.encode_www_form({
                              grant_type: GRANT_TYPE
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
        config.settings.token_path
      end
    end
  end
end
