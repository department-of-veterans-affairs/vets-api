# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'

module VeteranVerification
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.lighthouse.veteran_verification.timeout || 20

    API_SCOPES = %w[disability_rating.read enrolled_benefits.read flashes.read launch service_history.read
                    veteran_status.read].freeze
    VETERAN_VERIFICATION_PATH = 'services/veteran_verification/v2'
    TOKEN_PATH = 'oauth2/veteran-verification/system/v1/token'

    ##
    # @return [Config::Options] Settings for veteran_verification API.
    #
    def settings
      Settings.lighthouse.veteran_verification
    end

    ##
    # @return [String] Base path for veteran_verification URLs.
    #
    def base_path
      "#{settings.host}/#{VETERAN_VERIFICATION_PATH}"
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'VeteranVerification'
    end

    ##
    # @return [Faraday::Response] response from GET request
    #
    def get(path, params = {}, auth_params = {})
      connection.get(path, params, { Authorization: "Bearer #{access_token(auth_params)}" })
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
        faraday.use :breakers
        faraday.use Faraday::Response::RaiseError

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

    def access_token(auth_params = {})
      token_service.get_token(auth_params) if get_access_token?
    end

    def token_service
      url = "#{settings.host}/#{TOKEN_PATH}"
      token = settings.access_token

      @token_service ||= Auth::ClientCredentials::Service.new(
        url, API_SCOPES, token.client_id, token.aud_claim_url, token.rsa_key
      )
    end
  end
end
