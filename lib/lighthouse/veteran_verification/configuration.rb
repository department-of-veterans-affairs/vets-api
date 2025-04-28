# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'faraday/multipart'
require 'lighthouse/auth/client_credentials/jwt_generator'
require 'lighthouse/auth/client_credentials/service'

module VeteranVerification
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.lighthouse.veteran_verification.timeout || 20

    API_SCOPES = %w[disability_rating.read veteran_status.read].freeze
    VETERAN_VERIFICATION_PATH = 'services/veteran_verification/v2'
    TOKEN_PATH = 'oauth2/veteran-verification/system/v1/token'

    ##
    # @return [Config::Options] Settings for veteran_verification API.
    #
    def settings
      Settings.lighthouse.veteran_verification
    end

    ##
    # @param [String] host (optional): a configurable base url host if the client application does not want to
    #   use the default
    # @return [String] Base path for veteran_verification URLs.
    #
    def base_path(host = nil)
      (host || settings.host).to_s + "/#{VETERAN_VERIFICATION_PATH}"
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'VeteranVerification'
    end

    ##
    # @param [string] path: the endpoint to call
    # @param [string] lighthouse_client_id: client id retrieved from Lighthouse team to call Veteran Verification APIs
    # @param [string] lighthouse_rsa_key_path: the absolute path to the file that the client id was created from
    # @param [hash] options: options to override aud_claim_url, params, and auth_params
    # @option options [hash] :params body for the request
    # @option options [string] :aud_claim_url option to override the aud_claim_url for LH Veteran Verification APIs
    # @option options [hash] :auth_params a hash to send in auth params to create the access token
    #   such as the launch context
    # @option options [string] :host a base host for the Lighthouse API call
    def get(path, lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
      connection
        .get(
          path,
          options[:params],
          {
            Authorization: "Bearer #{
              access_token(
                lighthouse_client_id,
                lighthouse_rsa_key_path,
                options
              )
            }"
          }
        )
    end

    ##
    # Creates a Faraday connection with parsing json and breakers functionality.
    #
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      @conn ||= Faraday.new(base_api_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
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

    def token_service(lighthouse_client_id, lighthouse_rsa_key_path, aud_claim_url = nil, host = nil)
      # default client id and rsa key is used from the form526 block
      lighthouse_client_id = settings.form526.access_token.client_id if lighthouse_client_id.nil?
      lighthouse_rsa_key_path = settings.form526.access_token.rsa_key if lighthouse_rsa_key_path.nil?

      host ||= base_path(host)
      url = "#{host}/#{TOKEN_PATH}"
      aud_claim_url ||= settings.aud_claim_url

      @token_service ||= Auth::ClientCredentials::Service.new(
        url, API_SCOPES, lighthouse_client_id, aud_claim_url, lighthouse_rsa_key_path, 'veteran-verification'
      )
    end
  end
end
