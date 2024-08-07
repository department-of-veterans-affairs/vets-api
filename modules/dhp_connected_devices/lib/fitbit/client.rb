# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
# require_relative 'response'

module DhpConnectedDevices
  module Fitbit
    class MissingAuthError < StandardError; end
    class TokenExchangeError < StandardError; end
    class TokenRevocationError < StandardError; end

    class Client < Common::Client::Base
      configuration DhpConnectedDevices::Fitbit::Configuration
      ##
      # HTTP POST call to the Fitbit API to exchange a string of the auth code for a user token
      #
      # @return [Hash]
      def get_token(auth_code)
        resp = connection.post(config.base_path) do |req|
          req.headers = headers
          req.body = "client_id=#{Settings.dhp.fitbit.client_id}" \
                     "&code=#{auth_code}" \
                     "&code_verifier=#{CODE_VERIFIER}" \
                     '&grant_type=authorization_code' \
                     "&redirect_uri=#{Settings.dhp.fitbit.redirect_uri}"
        end

        raise "response code: #{resp.status}, response body: #{resp.body}" unless resp.status == 200

        JSON.parse(resp.body, symbolize_names: true)
      rescue => e
        raise TokenExchangeError, e.message.to_s
      end

      ##
      # Generates a Fitbit auth URL with PKCE code challenge
      #
      # @return [String]
      def auth_url_with_pkce
        "#{client.auth_url}&code_challenge=#{CODE_CHALLENGE}&code_challenge_method=S256"
      end

      ##
      # Retrieves auth code from callback_params
      #
      # @return [String]
      def get_auth_code(callback_params)
        raise MissingAuthError, "callback_params: #{callback_params}" unless callback_params[:code]

        callback_params[:code]
      end

      ##
      # Revokes fitbit access token
      #
      # @return [nil]
      # @raise TokenRevocationError
      def revoke_token(token)
        refresh_token = token[:refresh_token]
        resp = connection.post(config.revoke_token_base_path) do |req|
          req.headers = headers
          req.body = "token=#{refresh_token}"
        end
        raise "response code: #{resp.status}, response body: #{resp.body}" unless token_revoked?(resp, refresh_token)
      rescue => e
        raise TokenRevocationError, e.message.to_s
      end

      private

      def token_revoked?(resp, refresh_token)
        resp.status == 200 || token_revoked_by_user?(resp, refresh_token)
      end

      def token_revoked_by_user?(resp, refresh_token)
        resp_body = JSON.parse(resp.body).deep_symbolize_keys!
        token_has_been_revoked = resp_body[:errors].any? { |e| token_revoked_error?(e, refresh_token) }
        resp.status == 401 && token_has_been_revoked
      end

      def token_revoked_error?(error, refresh_token)
        error[:errorType] == 'invalid_token' && error[:message].include?("Access token invalid: #{refresh_token}")
      end

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
