# frozen_string_literal: true

module SOB
  module DGI
    class Configuration < ::Common::Client::Configuration::REST
      API_ROOT_PATH = '/external-api-service/api/v1'
      CERT_PATH = Settings.dgi.sob.jwt.public_key_path
      KEY_PATH = Settings.dgi.sob.jwt.private_key_path

      def connection
        @conn ||= Faraday.new(
          base_path, headers: base_request_headers, request: request_options, ssl: ssl_options
        ) do |faraday|
          faraday.use(:breakers, service_name:)
          faraday.response :raise_custom_error, error_prefix: service_name
          faraday.response :betamocks if mock_enabled?
          faraday.response :snakecase, symbolize: false
          faraday.response :json, content_type: /\bjson/
          faraday.adapter Faraday.default_adapter
        end
      end

      def service_name
        'SOB_CH33_STATUS'
      end

      def base_path
        "#{Settings.dgi.sob.claimants.url}#{API_ROOT_PATH}"
      end

      def mock_enabled?
        Settings.dgi.sob.claimants.mock || false
      end

      private

      def ssl_options
        if ssl_cert && ssl_key
          {
            client_cert: ssl_cert,
            client_key: ssl_key
          }
        end
      end

      def ssl_cert
        OpenSSL::X509::Certificate.new(File.read(CERT_PATH))
      end

      def ssl_key
        OpenSSL::PKey::RSA.new(File.read(KEY_PATH))
      end
    end
  end
end
