# frozen_string_literal: true

require 'common/client/configuration/rest'

module IAMSSOeOAuth
  # Configuration for the IAMSSOeOAuth::Service. A singleton class that returns
  # a connection that can make signed requests
  #
  # @example set the configuration in the service
  #   configuration IAMSSOeOAuth::Configuration
  #
  class Configuration < Common::Client::Configuration::REST
    CERT_PATH = Settings.iam_ssoe.client_cert_path
    KEY_PATH = Settings.iam_ssoe.client_key_path

    self.read_timeout = Settings.iam_ssoe.timeout || 15

    # Override the parent's base path
    # @return String the service base path from the environment settings
    #
    def base_path
      Settings.iam_ssoe.oauth_url
    end

    # Service name for breakers integration
    # @return String the service name
    #
    def service_name
      'IAMSSOeOAuth'
    end

    # Faraday connection object with breakers, snakecase and json response middleware
    # @return Faraday::Connection connection to make http calls
    #
    def connection
      Faraday.new(
        base_path, headers: base_request_headers, request: request_options, ssl: ssl_options
      ) do |conn|
        conn.use(:breakers, service_name:)
        conn.use Faraday::Response::RaiseError
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
      end
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
