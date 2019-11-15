# frozen_string_literal: true

require_relative './middleware/response/errors'

module VAOS
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.va_mobile.timeout || 15

    def base_path
      Settings.va_mobile.url
    end

    def service_name
      'VAOS'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers

        conn.request :json

        conn.response :betamocks if mock_enabled?
        conn.response :vaos_errors
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      [true, 'true'].include?(Settings.va_mobile.mock)
    end
  end
end
