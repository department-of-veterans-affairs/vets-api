# frozen_string_literal: true

require 'securerandom'
require_relative './base_client'

module TravelPay
  class TokenClient < TravelPay::BaseClient
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
    def request_btsss_token(veis_token, user)
      sts_token = request_sts_token(user)

      btsss_url = Settings.travel_pay.base_url
      client_number = Settings.travel_pay.client_number
      correlation_id = SecureRandom.uuid
      Rails.logger.debug(message: 'Correlation ID', correlation_id:)

      response = connection(server_url: btsss_url).post('api/v1/Auth/access-token') do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['BTSSS-API-Client-Number'] = client_number.to_s
        req.headers['X-Correlation-ID'] = correlation_id
        req.headers.merge!(claim_headers)
        req.body = { authJwt: sts_token }
      end

      response.body['data']['accessToken']
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

    def build_sts_assertion(user)
      service_account_id = Settings.travel_pay.sts.service_account_id
      host_baseurl = build_host_baseurl({ ip_form: false })
      audience_baseurl = build_host_baseurl({ ip_form: true })
      scopes = Settings.travel_pay.sts.scope.blank? ? [] : [Settings.travel_pay.sts.scope]

      current_time = Time.now.to_i
      jti = SecureRandom.uuid

      {
        'iss' => host_baseurl,
        'sub' => user.email,
        'aud' => "#{audience_baseurl}/v0/sign_in/token",
        'iat' => current_time,
        'exp' => current_time + 300,
        'scopes' => scopes,
        'service_account_id' => service_account_id,
        'jti' => jti,
        'user_attributes' => { 'icn' => user.icn }
      }
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

    def build_host_baseurl(config)
      env = Settings.vsp_environment
      host = Settings.hostname

      if env == 'localhost'
        if config[:ip_form]
          return 'http://127.0.0.1:3000'
        else
          return 'http://localhost:3000'
        end
      end

      "https://#{host}"
    end
  end
end