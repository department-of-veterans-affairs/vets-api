# frozen_string_literal: true

require 'securerandom'
require_relative './token_service'

module TravelPay
  class ClaimsClient
    ##
    # HTTP GET call to the BTSSS 'claims' endpoint
    # API responds with travel pay claims including status
    #
    # @return [TravelPay::Claim]
    #
    def get_claims(veis_token, btsss_token)
      request_claims(veis_token, btsss_token)
    end

    private

    def claim_headers
      if Settings.vsp_environment == 'production'
        {
          'Content-Type' => 'application/json',
          'Ocp-Apim-Subscription-Key-E' => Settings.travel_pay.subscription_key_e,
          'Ocp-Apim-Subscription-Key-S' => Settings.travel_pay.subscription_key_s
        }
      else
        {
          'Content-Type' => 'application/json',
          'Ocp-Apim-Subscription-Key' => Settings.travel_pay.subscription_key
        }
      end
    end

    def request_claims(veis_token, btsss_token)
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.debug(message: 'Correlation ID', correlation_id:)

      connection(server_url: btsss_url).get('api/v1/claims') do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['BTSSS-Access-Token'] = btsss_token
        req.headers['X-Correlation-ID'] = correlation_id
        req.headers.merge!(claim_headers)
      end
    end

    ##
    # Create a Faraday connection object
    # @return [Faraday::Connection]
    #
    def connection(server_url:)
      service_name = Settings.travel_pay.service_name

      Faraday.new(url: server_url) do |conn|
        conn.use :breakers
        conn.response :raise_custom_error, error_prefix: service_name, include_request: true
        conn.response :betamocks if mock_enabled?
        conn.response :json
        conn.request :json

        conn.adapter Faraday.default_adapter
      end
    end

    ##
    # Syntactic sugar for determining if the client should use
    # fake api responses or actually connect to the BTSSS API
    def mock_enabled?
      Settings.travel_pay.mock
    end

    def token_service
      TravelPay::TokenService.new
    end
  end
end
