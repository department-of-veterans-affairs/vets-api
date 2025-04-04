# frozen_string_literal: true

require 'common/client/configuration/soap'
require 'common/client/middleware/logging'

module MPI
  class Configuration < Common::Client::Configuration::SOAP
    def self.open_timeout
      IdentitySettings.mvi.open_timeout
    end

    def self.read_timeout
      IdentitySettings.mvi.timeout
    end

    def self.ssl_cert_path
      IdentitySettings.mvi.client_cert_path
    end

    def self.ssl_key_path
      IdentitySettings.mvi.client_key_path
    end

    def base_path
      IdentitySettings.mvi.url
    end

    def service_name
      'MVI'
    end

    def ssl_options
      if ssl_cert && ssl_key
        {
          client_cert: ssl_cert,
          client_key: ssl_key
        }
      end
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options, ssl: ssl_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :soap_headers

        # Uncomment this if you want curl command equivalent or response output to log
        # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
        # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

        conn.response :soap_parser
        conn.use :logging, 'MVIRequest' if IdentitySettings.mvi.pii_logging # Refactor as response middleware?
        conn.response :betamocks if IdentitySettings.mvi.mock
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
