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

      connection(server_url: auth_url).post("/#{tenant_id}/oauth2/token") do |req|
        req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
        req.body = URI.encode_www_form(veis_params)
      end
    end

    ##
    # HTTP POST call to the BTSSS token endpoint to get the access token
    #
    # @return [Faraday::Response]
    #
    def request_btsss_token(veis_token, vagov_token)
      btsss_url = Settings.travel_pay.base_url
      api_key = Settings.travel_pay.subscription_key

      connection(server_url: btsss_url).post("/api/v1/Auth/access-token") do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['Ocp-Apim-Subscription-Key'] = api_key
        req.body = { authJwt: vagov_token }
      end
    end

    ##
    # HTTP GET call to the BTSSS 'ping' endpoint to test liveness
    #
    # @return [Faraday::Response]
    #
    def ping(veis_token)
      btsss_url = Settings.travel_pay.base_url
      api_key = Settings.travel_pay.subscription_key

      connection(server_url: btsss_url).get("/api/v1/Sample/ping") do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['Ocp-Apim-Subscription-Key'] = api_key
      end
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
        conn.response :raise_error, error_prefix: service_name
        conn.response :betamocks if use_fakes?
        conn.response :json, { content_type: /\bjson/ }

        conn.adapter Faraday.default_adapter
      end
    end

    ##
    # Syntactic sugar for determining if the client should use 
    # fake api responses or actually connect to the BTSSS API
    def use_fakes?
      Settings.useFakes 
    end
  end
end

