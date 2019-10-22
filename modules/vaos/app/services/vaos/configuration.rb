# frozen_string_literal: true

module VAOS
  class Configuration < Common::Client::Configuration::REST
    def base_path
      Settings.va_mobile.url
    end

    def service_name
      'VAOS'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.use Faraday::Response::RaiseError

        conn.request :json

        conn.response :betamocks if mock_enabled?
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
      end
    end

    def parallel_connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.use Faraday::Response::RaiseError

        conn.request :json

        conn.response :betamocks if mock_enabled?
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.adapter :typhoeus
      end
    end

    def mock_enabled?
      [true, 'true'].include?(Settings.va_mobile.mock)
    end
  end
end
