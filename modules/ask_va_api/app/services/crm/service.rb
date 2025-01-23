# frozen_string_literal: true

module Crm
  class Service
    extend Forwardable

    attr_reader :icn, :logger, :settings, :token

    VEIS_API_PATH = 'eis/vagov.lob.ava/api'
    CRM_ENV = {
      'test' => 'iris-dev',
      'development' => 'iris-dev',
      'staging' => 'veft-qa',
      'production' => 'iris-PROD'
    }.freeze

    def_delegators :settings,
                   :base_url,
                   :veis_api_path,
                   :ocp_apim_subscription_key,
                   :service_name

    def initialize(icn:, logger: LogService.new)
      @settings = Settings.ask_va_api.crm_api
      @icn = icn
      @token = CrmToken.new.call
      @logger = logger
    end

    def call(endpoint:, method: :get, payload: {})
      endpoint = "#{VEIS_API_PATH}/#{endpoint}"
      organization = CRM_ENV[vsp_environment]

      params = { icn:, organizationName: organization }

      response = conn(url: base_url).public_send(method, endpoint, prepare_payload(method, payload, params)) do |req|
        req.headers = default_header.merge('Authorization' => "Bearer #{token}")
      end
      parse_response(response.body)
    rescue => e
      log_error(endpoint, service_name)
      Faraday::Response.new(response_body: e.original_body, status: e.original_status)
    end

    private

    def conn(url:)
      Faraday.new(url:) do |f|
        f.use :breakers
        f.response :raise_custom_error, error_prefix: service_name
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

    def vsp_environment
      Settings.vsp_environment
    end
  end
end
