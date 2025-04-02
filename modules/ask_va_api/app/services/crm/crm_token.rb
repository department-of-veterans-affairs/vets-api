# frozen_string_literal: true

module Crm
  class CrmToken
    extend Forwardable

    attr_reader :settings, :logger, :cache_client

    def_delegators :settings,
                   :auth_url,
                   :client_id,
                   :client_secret,
                   :tenant_id,
                   :service_name,
                   :resource

    def initialize
      @settings = Settings.ask_va_api.crm_api
      @cache_client = AskVAApi::RedisClient.new
      @logger = LogService.new
    end

    def call
      token = cache_client.fetch('token')

      return token if token.present?

      access_token = get_token

      cache_client.store_data(key: 'token', data: access_token, ttl: 3540)

      access_token
    end

    def get_token
      endpoint = "/#{tenant_id}/oauth2/token"

      response = conn(url: auth_url).post(endpoint) do |req|
        req.headers = token_headers
        req.body = URI.encode_www_form(auth_params)
      end

      result = parse_response(response.body)
      result[:access_token]
    rescue => e
      log_error(endpoint, service_name)
      raise e
    end

    private

    def conn(url:)
      Faraday.new(url:) do |f|
        f.use(:breakers, service_name:)
        f.response :raise_custom_error, error_prefix: service_name
        f.adapter Faraday.default_adapter
      end
    end

    def token_headers
      {
        'Content-Type' => 'application/x-www-form-urlencoded'
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

    def parse_response(body)
      JSON.parse(body, symbolize_names: true)
    end

    def build_tags(endpoint, error_or_status = nil)
      tags = { endpoint: }
      tags[:error] = error_or_status if error_or_status
      tags
    end

    def log_error(endpoint, error_type)
      logger.call('api_call.error', tags: build_tags(endpoint, error_type))
    end
  end
end
