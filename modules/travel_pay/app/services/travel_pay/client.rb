# frozen_string_literal: true

require 'securerandom'

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
    def request_btsss_token(veis_token, sts_token)
      btsss_url = Settings.travel_pay.base_url
      api_key = Settings.travel_pay.subscription_key
      client_number = Settings.travel_pay.client_number

      response = connection(server_url: btsss_url).post('api/v1/Auth/access-token') do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['Ocp-Apim-Subscription-Key'] = api_key
        req.headers['BTSSS-API-Client-Number'] = client_number.to_s
        req.body = { authJwt: sts_token }
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
      parse_claim_date = ->(c) { Date.parse(c[:modifiedOn]) }

      { data: symbolized_body[:data].sort_by(&parse_claim_date).reverse! }
    end

    def request_sts_token(user)
      return nil if mock_enabled?

      host_baseurl = build_host_baseurl({ ip_form: false })
      private_key_file = Settings.sign_in.sts_client.key_path
      private_key = OpenSSL::PKey::RSA.new(File.read(private_key_file))

      assertion = build_sts_assertion(user)
      jwt = JWT.encode(assertion, private_key, 'RS256')

      # send to sis
      response = connection(server_url: host_baseurl).post('/v0/sign_in/token') do |req|
        req.params['grant_type'] = 'urn:ietf:params:oauth:grant-type:jwt-bearer'
        req.params['assertion'] = jwt
      end

      response.body['data']['access_token']
    end

    private

    def build_sts_assertion(user)
      service_account_id = Settings.travel_pay.sts.service_account_id
      host_baseurl = build_host_baseurl({ ip_form: false })
      audience_baseurl = build_host_baseurl({ ip_form: true })

      current_time = Time.now.to_i
      jti = SecureRandom.uuid

      {
        'iss' => host_baseurl,
        'sub' => user.email,
        'aud' => "#{audience_baseurl}/v0/sign_in/token",
        'iat' => current_time,
        'exp' => current_time + 300,
        'scopes' => [],
        'service_account_id' => service_account_id,
        'jti' => jti,
        'user_attributes' => { 'icn' => user.icn }
      }
    end

    def build_host_baseurl(config)
      env = Settings.vsp_environment
      host = Settings.hostname

      if env == 'localhost'
        return 'http://127.0.0.1:3000' if config[:ip_form]

        'http://localhost:3000'
      end

      "https://#{host}"
    end

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
