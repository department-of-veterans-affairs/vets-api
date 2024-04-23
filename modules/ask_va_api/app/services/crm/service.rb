# frozen_string_literal: true

module Crm
  class Service
    extend Forwardable

    attr_reader :icn, :logger, :settings, :base_uri, :token

    BASE_URI = 'https://dev.integration.d365.va.gov'
    VEIS_API_PATH = 'eis/vagov.lob.ava/api'

    def_delegators :settings,
                   :base_url,
                   :veis_api_path,
                   :ocp_apim_subscription_key,
                   :service_name

    def initialize(icn:, base_uri: BASE_URI, logger: LogService.new)
      @settings = Settings.ask_va_api.crm_api
      @base_uri = base_uri
      @icn = icn
      @token = CrmToken.new.call
      @logger = logger
    end

    def call(endpoint:, method: :get, payload: {})
      endpoint = "#{VEIS_API_PATH}/#{endpoint}" if base_uri == BASE_URI

      params = { icn:, organizationName: 'iris-dev' }

      response = conn.public_send(method, endpoint, prepare_payload(method, payload, params)) do |req|
        req.headers = default_header.merge('Authorization' => "Bearer #{token}")
      end
      parse_response(response.body)
    rescue => e
      log_error(endpoint, service_name)
      Faraday::Response.new(response_body: e.original_body, status: e.original_status)
    end

    private

    def conn(url: base_uri)
      Faraday.new(url:) do |f|
        f.use :breakers
        f.response :raise_error, error_prefix: service_name
        f.adapter Faraday.default_adapter
      end
    end

    def prepare_payload(method, payload, params)
      case method
      when :get
        params.merge(payload)
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

    def default_header
      {
        'Content-Type' => 'application/json',
        'OCP-APIM-Subscription-Key' => ocp_apim_subscription_key
      }
    end
  end
end
