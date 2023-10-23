# frozen_string_literal: true

module Dynamics
  class Service
    SUPPORTED_METHODS = %i[get post patch put].freeze
    attr_reader :sec_id, :conn, :logger

    BASE_URI = 'https://run.mocky.io/v3/'

    def initialize(sec_id:, logger: LogService.new)
      @sec_id = sec_id
      @logger = logger
      setup_connection
    end

    def call(endpoint:, method: :get, payload: {})
      validate_method!(method)

      params = { sec_id: }
      execute_api_call(endpoint, method, payload, params)
    end

    private

    def validate_method!(method)
      raise ArgumentError, "Unsupported HTTP method: #{method}" unless SUPPORTED_METHODS.include?(method)
    end

    def setup_connection
      @conn = Faraday.new(url: BASE_URI) do |f|
        f.headers['Content-Type'] = 'application/json'
        f.request :url_encoded
        f.adapter Faraday.default_adapter
      end
    end

    def execute_api_call(endpoint, method, payload, params)
      response = invoke_request(endpoint, method, payload, params)
      ErrorHandler.handle(endpoint, response)
      parse_response(response.body)
    rescue ErrorHandler::ServiceError => e
      log_error(endpoint, e.class.name)
      raise e
    end

    def invoke_request(endpoint, method, payload, params)
      logger.call("api_call.#{method}", tags: build_tags(endpoint)) do
        conn.public_send(method, endpoint, prepare_payload(method, payload, params))
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
      tags = { endpoint:, sec_id: }
      tags[:error] = error_or_status if error_or_status
      tags
    end

    def log_error(endpoint, error_type)
      logger.call('api_call.error', tags: build_tags(endpoint, error_type))
    end
  end
end
