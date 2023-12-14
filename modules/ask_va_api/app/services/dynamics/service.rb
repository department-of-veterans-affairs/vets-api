# frozen_string_literal: true

module Dynamics
  class Service
    extend Forwardable

    attr_reader :icn, :logger, :settings, :base_uri

    BASE_URI = 'https://dev.integration.d365.va.gov'
    VEIS_API_PATH = 'veis/vagov.lob.ava/api'
    AUTH_URL = 'https://login.microsoftonline.us'

    def_delegators :settings,
                   :base_url,
                   :client_id,
                   :client_secret,
                   :veis_api_path,
                   :tenant_id,
                   :ocp_apim_subscription_key,
                   :service_name,
                   :resource

    def initialize(icn:, base_uri: BASE_URI, logger: LogService.new)
      @settings = Settings.ask_va_api.crm_api
      @base_uri = base_uri
      @icn = icn
      @logger = logger
    end

    def call(endpoint:, method: :get, payload: {})
      endpoint = "#{VEIS_API_PATH}/#{endpoint}" if base_uri == BASE_URI

      params = { icn: }

      response = conn.public_send(method, endpoint, prepare_payload(method, payload, params)) do |req|
        req.headers = default_header.merge('Authorization' => "Bearer #{token}")
      end
      parse_response(response.body)
    rescue => e
      log_error(endpoint, e.class.name)
      [e,
       {
         bearer: token,
         env: Rails.env,
         vsp_env: Settings.vsp_environment,
         tenant: tenant_id.chars.first(5),
         resource: resource.chars.first(5),
         client: client_id.chars.first(5),
         base_uri:
       }]
    end

    private

    def conn(url: base_uri)
      Faraday.new(url:) do |f|
        f.use :breakers
        f.adapter Faraday.default_adapter
      end
    end

    def prepare_payload(method, payload, params)
      case method
      when :get
        params
      when :post, :patch, :put
        payload.to_json
      end
    end

    def parse_response(body)
      JSON.parse(body, symbolize_names: true)
    end

    def build_tags(endpoint, error_or_status = nil)
      tags = { endpoint:, icn: }
      tags[:error] = error_or_status if error_or_status
      tags
    end

    def log_error(endpoint, error_type)
      logger.call('api_call.error', tags: build_tags(endpoint, error_type))
    end

    def token_headers
      {
        'Content-Type' => 'application/x-www-form-urlencoded'
      }
    end

    def default_header
      {
        'Content-Type' => 'application/json',
        'OCP-APIM-Subscription-Key' => ocp_apim_subscription_key
      }
    end

    def auth_params
      {
        client_id:,
        client_secret:,
        resource:,
        grant_type: 'client_credentials'
      }
    end

    def token
      response = conn(url: AUTH_URL).post("/#{tenant_id}/oauth2/token") do |req|
        req.headers = token_headers
        req.body = URI.encode_www_form(auth_params)
      end

      result = parse_response(response.body)
      result[:access_token] || result
    end
  end
end
