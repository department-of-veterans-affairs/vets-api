# frozen_string_literal: true

module TravelPay
  class Client
    ##
    # HTTP POST call to the VEIS Auth endpoint to get the access token
    #
    # @return [Faraday::Response]
    #
    def request_veis_token
      auth_url = Settings.travel_pay.veis.auth_url
      tenant_id = Settings.travel_pay.veis.tenant_id

      response = connection(server_url: auth_url).post("#{tenant_id}/oauth2/token") do |req|
        req.headers[:content_type] = 'application/x-www-form-urlencoded'
        req.body = URI.encode_www_form(veis_params)
      end

      response.body['access_token']
    end

    ##
    # HTTP POST call to the BTSSS token endpoint to get the access token
    #
    # @return [Faraday::Response]
    #
    def request_btsss_token(veis_token, vagov_token)
      btsss_url = Settings.travel_pay.base_url
      api_key = Settings.travel_pay.subscription_key
      client_number = Settings.travel_pay.client_number

      response = connection(server_url: btsss_url).post('api/v1/Auth/access-token') do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['Ocp-Apim-Subscription-Key'] = api_key
        req.headers['BTSSS-API-Client-Number'] = client_number.to_s
        req.body = { authJwt: vagov_token }
      end
      response.body['access_token']
    end

    ##
    # HTTP GET call to the BTSSS 'ping' endpoint to test liveness
    #
    # @return [Faraday::Response]
    #
    def ping(veis_token)
      btsss_url = Settings.travel_pay.base_url
      api_key = Settings.travel_pay.subscription_key

      connection(server_url: btsss_url).get('api/v1/Sample/ping') do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['Ocp-Apim-Subscription-Key'] = api_key
      end
    end

    ##
    # HTTP GET call to the BTSSS 'authorized-ping' endpoint to test liveness
    #
    # @return [Faraday::Response]
    #
    def authorized_ping(veis_token, btsss_token)
      btsss_url = Settings.travel_pay.base_url
      api_key = Settings.travel_pay.subscription_key

      connection(server_url: btsss_url).get('api/v1/Sample/authorized-ping') do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['BTSSS-Access-Token'] = btsss_token
        req.headers['Ocp-Apim-Subscription-Key'] = api_key
      end
    end

    ##
    # HTTP GET call to the BTSSS 'claims' endpoint
    # API responds with travel pay claims including status
    #
    # @return [TravelPay::Claim]
    #
    def get_claims(veis_token, btsss_token)
      btsss_url = Settings.travel_pay.base_url
      api_key = Settings.travel_pay.subscription_key

      response = connection(server_url: btsss_url).get('api/v1/claims') do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['BTSSS-Access-Token'] = btsss_token
        req.headers['Ocp-Apim-Subscription-Key'] = api_key
      end

      symbolized_body = response.body.deep_symbolize_keys
      parse_claim_date = ->(c) { Date.parse(c[:modified_on]) }
      symbolized_body[:data].sort_by(&parse_claim_date).reverse!
    end

    private

    def veis_params
      {
        client_id: Settings.travel_pay.veis.client_id,
        client_secret: Settings.travel_pay.veis.client_secret,
        client_info: 1,
        grant_type: 'client_credentials',
        resource: Settings.travel_pay.veis.resource
      }
    end

    ##
    # Create a Faraday connection object
    # @return [Faraday::Connection]
    #
    def connection(server_url:)
      service_name = Settings.travel_pay.service_name

      Faraday.new(url: server_url) do |conn|
        conn.use :breakers
        conn.response :raise_error, error_prefix: service_name, include_request: true
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
  end
end
