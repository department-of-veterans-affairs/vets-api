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
    # @param [String] host (optional): a configurable base url host if the client application does not want to
    #   use the default
    # @return [String] Base path for veteran_verification URLs.
    #
    def base_path(host = nil)
      (host || settings.host).to_s
    end

    def base_api_path(host = nil)
      "#{base_path(host)}/#{CLAIMS_PATH}"
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
    def get(path, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      connection.get(path, options[:params], { Authorization: "Bearer #{
        access_token(
          lighthouse_client_id,
          lighthouse_rsa_key_path,
          options
        )
      }" })
    end

    ##
    # @return [Faraday::Response] response from POST request
    #
    def post(path, body, lighthouse_client_id, lighthouse_rsa_key_path, options = {})
      connection.post(path, body, { Authorization: "Bearer #{
        access_token(
          lighthouse_client_id,
          lighthouse_rsa_key_path,
          options
        )
      }" })
    end

    ##
    # Creates a Faraday connection with parsing json and breakers functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      @conn ||= Faraday.new(base_api_path, headers: base_request_headers, request: request_options) do |faraday|
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

    def access_token(lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      if get_access_token?
        token_service(
          lighthouse_client_id,
          lighthouse_rsa_key_path,
          options[:aud_claim_url],
          options[:host]
        ).get_token(options[:auth_params])
      end
    end

    ##
    # @return [BenefitsClaims::AccessToken::Service] Service used to generate access tokens.
    #
    def token_service(lighthouse_client_id, lighthouse_rsa_key_path, aud_claim_url = nil, host = nil)
      lighthouse_client_id = settings.access_token.client_id if lighthouse_client_id.nil?
      lighthouse_rsa_key_path = settings.access_token.rsa_key if lighthouse_rsa_key_path.nil?
      host ||= base_path(host)
      url = "#{host}/#{TOKEN_PATH}"
      aud_claim_url ||= settings.access_token.aud_claim_url

      @token_service ||= Auth::ClientCredentials::Service.new(
        url, API_SCOPES, lighthouse_client_id, aud_claim_url, lighthouse_rsa_key_path
      )
    end
  end
end
