# frozen_string_literal: true

module Idp
  class Client
    DEFAULT_TIMEOUT = 15

    def initialize(base_url: nil, timeout: nil)
      @base_url = base_url.presence ||
                  Settings.dig(:cave, :idp, :base_url) ||
                  ENV.fetch('IDP_API_BASE_URL', nil)
      @timeout = timeout ||
                 Settings.dig(:cave, :idp, :timeout) ||
                 ENV['IDP_API_TIMEOUT']&.to_i ||
                 DEFAULT_TIMEOUT
      raise Idp::Error, 'IDP base URL is not configured' if @base_url.blank?
    end

    def intake(file_name:, pdf_base64:)
      post('intake', { pdf_b64: pdf_base64 }, 'X-Filename' => file_name)
    end

    def status(id)
      get('status', { id: })
    end

    def output(id, type:)
      get('output', { id:, type: })
    end

    def download(id, kvpid:)
      get('download', { id:, kvpid: })
    end

    private

    attr_reader :base_url, :timeout

    def connection
      @connection ||= Faraday.new(url: normalized_base_url) do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.response :raise_error
        conn.options.timeout = timeout
        conn.options.open_timeout = timeout
        conn.adapter Faraday.default_adapter
      end
    end

    def normalized_base_url
      base_url.end_with?('/') ? base_url : "#{base_url}/"
    end

    def get(path, params = {})
      perform_request { connection.get(path, params) }
    end

    def post(path, body, headers = {})
      perform_request do
        connection.post(path) do |req|
          req.headers['Content-Type'] = 'application/json'
          headers.each do |key, value|
            req.headers[key] = value if value.present?
          end
          req.body = body
        end
      end
    end

    def perform_request
      response = yield
      response.body
    rescue Faraday::Error => e
      raise Idp::Error, e.message
    end
  end
end
