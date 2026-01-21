# lib/decision_reviews/v1/appealable_issues/configuration.rb
# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'lighthouse/auth/client_credentials/service'

module DecisionReviews
  module V1
    module AppealableIssues
      class Configuration < Common::Client::Configuration::REST
        self.read_timeout = Settings.decision_review.appealable_issues.timeout || 30
        self.open_timeout = Settings.decision_review.appealable_issues.timeout || 30

        # API paths
        BASE_PATH = 'services/appeals/appealable-issues/v0'
        HIGHER_LEVEL_REVIEWS_PATH = "#{BASE_PATH}/appealable-issues/higher-level-reviews".freeze
        NOTICE_OF_DISAGREEMENT_PATH = "#{BASE_PATH}/appealable-issues/notice-of-disagreements".freeze
        SUPPLEMENTAL_CLAIMS_PATH = "#{BASE_PATH}/appealable-issues/supplemental-claims".freeze
        TOKEN_PATH = 'oauth2/appeals/system/v1/token'

        # API configuration
        API_SCOPES = ['system/AppealableIssues.read'].freeze
        DEFAULT_BENEFIT_TYPE = 'compensation'

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
        # Get appealable issues for higher level reviews
        # Automatically sets benefit_type to 'compensation' as it's required and most common
        #
        # @param [String] icn - Veteran's ICN
        # @param [String] benefit_type - Type of benefit (defaults to 'compensation')
        # @return [Faraday::Response] response from GET request
        #
        def get_higher_level_review_issues(icn:, benefit_type: DEFAULT_BENEFIT_TYPE)
          headers = { 'Authorization' => "Bearer #{access_token}" }
          query = {
            icn:,
            benefitType: benefit_type,
            receiptDate: Time.zone.now.strftime('%Y-%m-%d')
          }

          connection.get(HIGHER_LEVEL_REVIEWS_PATH, query, headers)
        end

        ##
        # Get appealable issues for notice of disagreement
        # Automatically sets benefit_type to 'compensation' as it's required and most common
        #
        # @param [String] icn - Veteran's ICN
        # @param [String] benefit_type - Type of benefit (defaults to 'compensation')
        # @return [Faraday::Response] response from GET request
        #
        def get_notice_of_disagreement_issues(icn:, benefit_type: DEFAULT_BENEFIT_TYPE)
          headers = { 'Authorization' => "Bearer #{access_token}" }
          query = {
            icn:,
            benefitType: benefit_type,
            receiptDate: Time.zone.now.strftime('%Y-%m-%d')
          }

          connection.get(NOTICE_OF_DISAGREEMENT_PATH, query, headers)
        end

        ##
        # Get appealable issues for supplemental claims
        # Automatically sets benefit_type to 'compensation' as it's required and most common
        #
        # @param [String] icn - Veteran's ICN
        # @param [String] benefit_type - Type of benefit (defaults to 'compensation')
        # @return [Faraday::Response] response from GET request
        #
        def get_supplemental_claim_issues(icn:, benefit_type: DEFAULT_BENEFIT_TYPE)
          headers = { 'Authorization' => "Bearer #{access_token}" }
          query = {
            icn:,
            benefitType: benefit_type,
            receiptDate: Time.zone.now.strftime('%Y-%m-%d')
          }

          connection.get(SUPPLEMENTAL_CLAIMS_PATH, query, headers)
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
            File.read(config.rsa_key_path),
            'decision_reviews_appealable_issues'
          )
        end
      end
    end
  end
end
