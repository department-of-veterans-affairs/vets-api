# frozen_string_literal: true

require 'common/client/configuration/soap'

module MVI
  class Configuration < Common::Client::Configuration::SOAP
    # :nocov:
    def self.default_mvi_open_timeout
      Rails.logger.warn 'Settings.mvi.open_timeout not set, using default'
      2
    end

    def self.default_mvi_timeout
      Rails.logger.warn 'Settings.mvi.timeout not set, using default'
      10
    end
    # :nocov:

    OPEN_TIMEOUT = Settings.mvi.open_timeout&.to_i || default_mvi_open_timeout
    TIMEOUT = Settings.mvi.timeout&.to_i || default_mvi_timeout

    def self.ssl_cert_path
      Settings.mvi.client_cert_path
    end

    def self.ssl_key_path
      Settings.mvi.client_key_path
    end

    def base_path
      Settings.mvi.url
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
        conn.request :soap_headers
        conn.response :soap_parser
        conn.use :breakers
        conn.response :betamocks if Settings.mvi.mock
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
