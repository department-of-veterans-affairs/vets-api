# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'

module BenefitsClaims
  ##
  # HTTP client configuration for the {BenefitsClaims::Service},
  # sets the base path, the base request headers, and a service name for breakers and metrics.
  #
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.lighthouse.benefits_claims.timeout || 20

    API_SCOPES = %w[system/claim.read system/claim.write].freeze
    CLAIMS_PATH = 'services/claims/v2/veterans'
    TOKEN_PATH = 'oauth2/claims/system/v1/token'

    ##
    # @return [Config::Options] Settings for benefits_claims API.
    #
    def settings
      Settings.lighthouse.benefits_claims
    end

    ##
    # @return [String] Base path for benefits_claims URLs.
    #
    def base_path
      "#{settings.host}/#{CLAIMS_PATH}"
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'BenefitsClaims'
    end

    ##
    # @return [Faraday::Response] response from GET request
    #
    def get(path, params = {})
      connection.get(path, params, { Authorization: "Bearer #{access_token}" })
    end

    ##
    # @return [Faraday::Response] response from POST request
    #
    def post(path, body = {})
      connection.post(path, body, { Authorization: "Bearer #{access_token}" })
    end

    ##
    # Creates a Faraday connection with parsing json and breakers functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use      :breakers
        faraday.use      Faraday::Response::RaiseError

        faraday.request :multipart
        faraday.request :json

        faraday.response :betamocks if use_mocks?
        faraday.response :json
        faraday.adapter Faraday.default_adapter
      end
    end

    private

    ##
    # @return [Boolean] Should the service use mock data in lower environments.
    #
    def use_mocks?
      settings.use_mocks || false
    end

    def get_access_token?
      !use_mocks? || Settings.betamocks.recording
    end

    def access_token
      token_service.get_token if get_access_token?
    end

    ##
    # @return [BenefitsClaims::AccessToken::Service] Service used to generate access tokens.
    #
    def token_service
      url = "#{settings.host}/#{TOKEN_PATH}"
      token = settings.access_token

      @token_service ||= Auth::ClientCredentials::Service.new(
        url, API_SCOPES, token.client_id, token.aud_claim_url, token.rsa_key
      )
    end
  end
end
