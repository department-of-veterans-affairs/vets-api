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
        conn.request :camelcase
        conn.request :json

        conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
        conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

        conn.response :betamocks if mock_enabled?
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.response :vaos_errors # vaos errors are rarely JSON, this needs to be lower in middleware stack
        conn.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      [true, 'true'].include?(Settings.va_mobile.mock)
    end
  end
end
