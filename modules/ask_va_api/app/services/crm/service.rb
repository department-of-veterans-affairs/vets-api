# frozen_string_literal: true

module Crm
  class Service
    extend Forwardable

    attr_reader :icn, :logger, :settings, :token

    CRM_ENV = {
      'test' => 'iris-dev',
      'development' => 'iris-dev',
      'staging' => 'veft-preprod',
      'production' => 'veft'
    }.freeze

    def_delegators :settings,
                   :base_url,
                   :veis_api_path,
                   :ocp_apim_subscription_key,
                   :service_name,
                   :e_subscription_key,
                   :s_subscription_key

    def initialize(icn:, logger: LogService.new)
      @settings = Settings.ask_va_api.crm_api
      @icn = icn
      @token = CrmToken.new.call
      @logger = logger
    end

    # Calls the CRM API with given method, endpoint, and optional payload
    def call(endpoint:, method: :get, payload: {})
      organization = CRM_ENV[vsp_environment]
      uri = build_uri(endpoint, method, organization)
      response = conn(url: base_url).public_send(method, uri, request_body(method, payload, organization)) do |req|
        req.headers = request_headers
      end

      parse_response(response.body)
    rescue => e
      log_error(uri, service_name)

      Faraday::Response.new(
        response_body: extract_body_from(e),
        status: extract_status_from(e)
      )
    end

    private

    def conn(url:)
      Faraday.new(url:) do |f|
        f.use(:breakers, service_name:)
        f.response :raise_custom_error, error_prefix: service_name
        f.adapter Faraday.default_adapter
      end
    end

    def vsp_environment
      Settings.vsp_environment
    end

    def build_uri(endpoint, method, organization)
      uri = URI.parse("#{veis_api_path}/#{endpoint}")
      uri.query = URI.encode_www_form(organizationName: organization) if method == :put
      uri.to_s
    end

    def request_body(method, payload, organization)
      case method
      when :get
        { organizationName: organization }.merge(payload)
      when :post, :patch, :put
        payload.to_json
      end
    end

    def request_headers
      base = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{token}",
        'X-VA-ICN' => icn
      }

      env_headers = if vsp_environment == 'production'
                      {
                        'OCP-APIM-Subscription-Key-E' => e_subscription_key,
                        'OCP-APIM-Subscription-Key-S' => s_subscription_key
                      }
                    else
                      {
                        'OCP-APIM-Subscription-Key' => ocp_apim_subscription_key
                      }
                    end

      base.merge(env_headers)
    end

    def parse_response(body)
      JSON.parse(body, symbolize_names: true)
    end

    def extract_body_from(error)
      return error.original_body if error.respond_to?(:original_body)

      if error.respond_to?(:response) && error.response.is_a?(Hash)
        error.response[:body] || error.message
      else
        { error: error.message }
      end
    end

    def extract_status_from(error)
      return error.original_status if error.respond_to?(:original_status)

      if error.respond_to?(:response) && error.response.is_a?(Hash)
        error.response[:status] || 500
      else
        500
      end
    end

    def log_error(endpoint, error_type)
      logger.call('api_call.error', tags: {
                    endpoint:,
                    error: error_type
                  })
    end
  end
end
