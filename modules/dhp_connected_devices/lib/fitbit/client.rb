# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
# require_relative 'response'

module DhpConnectedDevices
  module Fitbit
    class Client < Common::Client::Base
      configuration DhpConnectedDevices::Fitbit::Configuration

      ##
      # HTTP POST call to the Fitbit API to exchange auth code for a user token
      #
      # @return [Faraday::Response]
      #
      def get_token(auth_code)
        connection.post(config.base_path) do |req|
          req.headers = headers
          req.body = "client_id=#{Settings.dhp.fitbit.client_id}" \
                     "&code=#{auth_code}" \
                     "&code_verifier=#{CODE_VERIFIER}" \
                     '&grant_type=authorization_code' \
                     "&redirect_uri=#{Settings.dhp.fitbit.redirect_uri}"
        end
      end

      ##
      # Generates a Fitbit auth URL with PKCE code challenge
      #
      # @return [String]
      #
      def auth_url_with_pkce
        "#{client.auth_url}&code_challenge=#{CODE_CHALLENGE}&code_challenge_method=S256"
      end

      private

      def client
        @client ||= FitbitAPI::Client.new(redirect_uri: Settings.dhp.fitbit.redirect_uri,
                                          scope: Settings.dhp.fitbit.scope)
      end

      def headers
        {
          'Authorization' => "Basic #{basic_auth}",
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
      end

      def basic_auth
        Base64.urlsafe_encode64("#{Settings.dhp.fitbit.client_id}:#{Settings.dhp.fitbit.client_secret}")
      end
    end
  end
end
