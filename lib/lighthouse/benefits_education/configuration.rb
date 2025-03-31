# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'lighthouse/auth/client_credentials/service'

module BenefitsEducation
  ##
  # HTTP client configuration for the {BenefitsEducation::Service},
  # sets the base path, the base request headers, and a service name for breakers and metrics.
  #
  class Configuration < Common::Client::Configuration::REST
    SYSTEM_NAME = 'VA.gov'
    TOKEN_PATH = 'oauth2/benefits-education/system/v1/token'
    API_PATH = 'services/benefits-education/v1/education/chapter33'

    # Scopes can be found here:
    # https://developer.va.gov/explore/api/education-benefits/client-credentials#:~:text=Retrieving%20an%20access%20token
    API_SCOPES = %w[education.read].freeze

    ##
    # @return [Config::Options] Settings for Lighthouse benefits_education API.
    #
    def benefits_education_settings
      Settings.lighthouse.benefits_education
    end

    ##
    # @return [String] API endpoint for benefits_education
    #
    def base_path
      "#{benefits_education_settings.host}/#{API_PATH}"
    end

    ##
    # @return [String] Service name to use in breakers and metrics.
    #
    def service_name
      'BENEFITS_EDUCATION'
    end

    ##
    # @param [String] icn: Veteran's icn
    # @return [Faraday::Response] response from GET request: A veteran's education benefits
    #
    def get(icn)
      connection.get('', { icn: }, { Authorization: "Bearer #{access_token}" })
    end

    ##
    # Creates a Faraday connection with parsing json and breakers functionality.
    # @return [Faraday::Connection] a Faraday connection instance.
    #
    def connection
      @conn ||= Faraday.new(base_path, headers: base_request_headers, request: request_options) do |faraday|
        faraday.use(:breakers, service_name:)
        faraday.use Faraday::Response::RaiseError

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
      benefits_education_settings.use_mocks || false
    end

    ##
    # @return [Boolean] Should the service make a call out to retrieve an access token
    def get_access_token?
      !use_mocks? || Settings.betamocks.recording
    end

    ##
    # @return [String] a Bearer token to be included in requests to the Lighthouse API
    def access_token
      token_service.get_token if get_access_token?
    end

    ##
    # @return [Auth::ClientCredentials::Service] Service used to generate access token,
    #   used when making a request to the Lighthouse API
    #
    def token_service
      lighthouse_client_id = benefits_education_settings.access_token.client_id
      lighthouse_rsa_key_path = benefits_education_settings.access_token.rsa_key
      token_url = "#{benefits_education_settings.host}/#{TOKEN_PATH}"

      # aud_claim_url found here:
      # https://developer.va.gov/explore/api/education-benefits/client-credentials#:~:text=Description-,aud,-True
      aud_claim_url ||= benefits_education_settings.access_token.aud_claim_url

      @token_service ||= Auth::ClientCredentials::Service.new(
        token_url,
        API_SCOPES,
        lighthouse_client_id,
        aud_claim_url,
        lighthouse_rsa_key_path,
        'benefits-education'
      )
    end
  end
end
