# frozen_string_literal: true

require 'common/client/configuration/rest'

module CheckIn
  module VAOS
    class Configuration < Common::Client::Configuration::REST
      self.read_timeout = Settings.va_mobile.timeout || 55

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

          # Uncomment this if you want curl command equivalent or response output to log
          # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
          # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

          conn.response :raise_error, error_prefix: service_name
          conn.response :betamocks if mock_enabled?
          # conn.response :snakecase
          conn.response :json, content_type: /\bjson$/

          conn.adapter Faraday.default_adapter
        end
      end

      def mock_enabled?
        [true, 'true'].include?(Settings.check_in.vaos.mock)
      end
    end
  end
end
