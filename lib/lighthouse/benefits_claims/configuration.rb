# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'faraday/multipart'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'

module BenefitsClaims
  ##
  # HTTP client configuration for the {BenefitsClaims::Service},
  # sets the base path, the base request headers, and a service name for breakers and metrics.
  #
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.lighthouse.benefits_claims.timeout || 30

    API_SCOPES = %w[system/claim.read system/claim.write system/526-pdf.override system/526.override].freeze
    CLAIMS_PATH = 'services/claims/v2/veterans'
    TOKEN_PATH = 'oauth2/claims/system/v1/token'

    def auth_settings
      Settings.ligthouse.auth.ccg
    end

    ##
    # @return [Config::Options] Settings for benefits_claims API.
    #
    def settings
      Settings.lighthouse.benefits_claims
    end

    ##
    # @param [String] host (optional): a configurable base url host if the client application does not want to
    #   use the default
    # @return [String] Base path for veteran_verification URLs.
    #
    def base_api_path
      settings.host
    end

    def base_path
      "#{base_api_path}/#{CLAIMS_PATH}"
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'BenefitsClaims'
    end

    delegate :get, :post, to: :connection

    ##
    # Makes a POST request with custom query parameters
    #
    # @return [Faraday::Response] response from POST request
    #
    def post_with_params(path, body, params)
      connection.post(path) do |req|
        req.body = body
        req.params = params
      end
    end

    ##
    # Creates a Faraday connection with parsing json and breakers functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use :breakers
        faraday.use Faraday::Response::RaiseError

        faraday.request :authorization, 'Bearer', -> { access_token }
        faraday.request :multipart
        faraday.request :json

        faraday.response :betamocks if use_mocks?
        faraday.response :json, content_type: /\bjson/

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
      client_id = auth_settings.client_id if settings.access_token.client_id.nil?
      rsa_key_path = auth_settings.rsa_key if settings.access_token.rsa_key_path.nil?
      aud_claim_url ||= settings.access_token.aud_claim_url

      url = "#{base_path}/#{TOKEN_PATH}"

      @token_service ||= Auth::ClientCredentials::Service.new(
        url, API_SCOPES, client_id, aud_claim_url, rsa_key_path, 'benefits-claims'
      )
    end
  end
end
