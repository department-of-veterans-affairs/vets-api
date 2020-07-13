# frozen_string_literal: true

require_relative './middleware/response/errors'
require_relative './middleware/vaos_logging'

module VAOS
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.va_mobile.timeout || 15

    def base_path
      Settings.va_mobile.url
    end

    def service_name
      'VAOS'
    end

    def rsa_key
      @key ||= OpenSSL::PKey::RSA.new(File.read(Settings.va_mobile.key_path))
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.request :camelcase
        conn.request :json

        if ENV['VAOS_DEBUG'] && !Rails.env.production?
          conn.request(:curl, ::Logger.new(STDOUT), :warn)
          conn.response(:logger, ::Logger.new(STDOUT), bodies: true)
        end

        conn.response :betamocks if mock_enabled?
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.response :vaos_errors
        conn.use :vaos_logging
        conn.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      [true, 'true'].include?(Settings.va_mobile.mock)
    end
  end
end
