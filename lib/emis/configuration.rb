# frozen_string_literal: true

require 'common/client/configuration/soap'

module EMIS
  # Configuration for {EMIS::Service}
  # includes SSL options and the configured Faraday object
  #
  class Configuration < Common::Client::Configuration::SOAP
    # :nocov:

    # EMIS SSL certificate path
    # @return [String] EMIS SSL certificate path
    def self.ssl_cert_path
      Settings.emis.client_cert_path
    end

    # EMIS SSL key path
    # @return [String] EMIS SSL key path
    def self.ssl_key_path
      Settings.emis.client_key_path
    end
    # :nocov:

    # Faraday SSL options
    # @return [Hash] Faraday SSL options
    def ssl_options
      if ssl_cert && ssl_key
        {
          client_cert: ssl_cert,
          client_key: ssl_key
        }
      end
    end

    # Faraday connection object configured to handle SOAP requests
    # @return [Faraday::Connection] Faraday connection object
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options, ssl: ssl_options) do |conn|
        conn.use :breakers
        conn.request :soap_headers

        conn.response :soap_parser
        conn.response :betamocks if Settings.emis.mock
        conn.adapter Faraday.default_adapter
      end
    end

    # Allow connection to be used without certificates present
    # @return [Boolean]
    def allow_missing_certs?
      true
    end
  end
end
