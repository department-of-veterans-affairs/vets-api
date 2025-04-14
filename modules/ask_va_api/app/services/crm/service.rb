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

    def call(endpoint:, method: :get, payload: {})
      organization = CRM_ENV[vsp_environment]
      # Construct endpoint with optional query parameters
      uri = URI.parse("#{veis_api_path}/#{endpoint}")
      uri.query = URI.encode_www_form(organizationName: organization) if method == :put
      endpoint = uri.to_s

      # Prepare request details
      request_payload = prepare_payload(method, payload, { icn:, organizationName: organization })
      headers = default_header.merge('Authorization' => "Bearer #{token}")
      # Make the request
      response = conn(url: base_url).public_send(method, endpoint, request_payload) do |req|
        req.headers = headers
      end
      parse_response(response.body)
    rescue => e
      log_error(endpoint, service_name)

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
      if Settings.vsp_environment == 'production'
        {
          'Content-Type' => 'application/json',
          'OCP-APIM-Subscription-Key-E' => e_subscription_key,
          'OCP-APIM-Subscription-Key-S' => s_subscription_key
        }
      else
        {
          'Content-Type' => 'application/json',
          'OCP-APIM-Subscription-Key' => ocp_apim_subscription_key
        }
      end
    end

    def vsp_environment
      Settings.vsp_environment
    end
  end
end
