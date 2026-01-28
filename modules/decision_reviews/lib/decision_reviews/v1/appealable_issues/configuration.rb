# lib/decision_reviews/v1/appealable_issues/configuration.rb
# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'lighthouse/auth/client_credentials/service'

module DecisionReviews
  module V1
    module AppealableIssues
      class Configuration < Common::Client::Configuration::REST
        self.read_timeout = Settings.caseflow.timeout || 20 # using the same timeout as lighthouse

        # API configuration
        API_SCOPES = ['system/AppealableIssues.read'].freeze

        def base_path
          Settings.decision_review.appealable_issues.url
        end

        def service_name
          'DecisionReviews_AppealableIssues'
        end

        def mock_enabled?
          Settings.decision_review.appealable_issues.mock || false
        end

        ##
        # Returns authorization headers for API requests
        #
        # @return [Hash] Headers hash with Bearer token
        #
        def auth_headers
          { 'Authorization' => "Bearer #{access_token}" }
        end

        ##
        # Creates a Faraday connection with parsing json and breakers functionality.
        #
        # @return [Faraday::Connection] a Faraday connection instance.
        #
        def connection
          @connection ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
            faraday.use(:breakers, service_name:)
            faraday.use Faraday::Response::RaiseError

            faraday.request :json

            faraday.response :betamocks if mock_enabled?
            faraday.response :json, content_type: /\bjson/
            faraday.adapter Faraday.default_adapter
          end
        end

        private

        ##
        # Gets access token for API requests
        #
        # @return [String] the access token
        #
        def access_token
          return nil if mock_enabled? && !Settings.betamocks&.recording

          token_service.get_token
        end

        ##
        # Creates the OAuth token service
        #
        # @return [Auth::ClientCredentials::Service] Service used to generate access tokens
        #
        def token_service
          config = Settings.decision_review.appealable_issues.auth

          @token_service ||= Auth::ClientCredentials::Service.new(
            config.token_url,
            API_SCOPES,
            config.client_id,
            config.aud_claim_url,
            rsa_key,
            'decision_reviews_appealable_issues'
          )
        end

        ##
        # Reads the RSA private key from file
        #
        # @return [String] the RSA private key content
        #
        def rsa_key
          @rsa_key ||= File.read(Settings.decision_review.appealable_issues.auth.rsa_key)
        end
      end
    end
  end
end
