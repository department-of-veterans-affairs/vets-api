# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'

module DirectDeposit
  ##
  # HTTP client configuration for the {DirectDeposit::Service},
  # sets the base path, the base request headers, and a service name for breakers and metrics.
  #
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.lighthouse.direct_deposit.timeout || 20

    API_SCOPES = %w[direct.deposit.read direct.deposit.write].freeze
    DIRECT_DEPOSIT_PATH = 'services/direct-deposit-management/v1/direct-deposit'
    TOKEN_PATH = 'oauth2/direct-deposit-management/system/v1/token'

    ##
    # @return [Config::Options] Settings for direct_deposit API.
    #
    def settings
      Settings.lighthouse.direct_deposit
    end

    ##
    # @return [String] Base path for direct_deposit URLs.
    #
    def base_path
      "#{settings.host}/#{DIRECT_DEPOSIT_PATH}"
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'LIGHTHOUSE_DIRECT_DEPOSIT'
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
    def put(path, body = {})
      connection.put(path, body, { Authorization: "Bearer #{access_token}" })
    end

    ##
    # Creates a Faraday connection with parsing json and breakers functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError
        faraday.request :json

        faraday.response :betamocks if use_mocks?
        faraday.response :snakecase, symbolize: false
        faraday.response :json, content_type: /\bjson/

        faraday.adapter Faraday.default_adapter
      end
    end

    def access_token
      token_service.get_token if get_access_token?
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

    ##
    # @return [Auth::ClientCredentials::Service] Service used to generate access tokens.
    #
    def token_service
      url = "#{settings.host}/#{TOKEN_PATH}"
      token = settings.access_token

      @token_service ||= Auth::ClientCredentials::Service.new(
        url, API_SCOPES, token.client_id, token.aud_claim_url, token.rsa_key, 'direct-deposit'
      )
    end
  end
end
