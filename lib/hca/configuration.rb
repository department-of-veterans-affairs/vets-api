# frozen_string_literal: true
require 'common/client/configuration/soap'
require 'common/client/middleware/request/soap_headers'
require 'common/client/middleware/response/soap_parser'

module HCA
  module Configuration
    def self.cert_store(paths)
      store = OpenSSL::X509::Store.new
      Array(paths).each do |path|
        store.add_file(Rails.root.join('config', 'health_care_application', 'certs', path).to_s)
      end
      store
    end

    WSDL = Rails.root.join('config', 'health_care_application', 'wsdl', 'voa.wsdl')
    CERT_STORE = if Settings.hca.ca&.empty?
                   nil
                 else
                   cert_store(Settings.hca.ca)
                 end

    def self.ssl_cert_path
      Settings.hca.cert_path
    end

    def self.ssl_key_path
      Settings.hca.key_path
    end

    def ssl_options
      ssl = {
        verify: true
      }
      if HCA::Configuration::CERT_STORE
        ssl[:cert_store] = HCA::Configuration::CERT_STORE
      end
      if ssl_cert && ssl_key
        ssl[:client_cert] = ssl_cert
        ssl[:client_key] = ssl_key
      end
      ssl
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options, ssl: ssl_options) do |conn|
        conn.options.open_timeout = 10  # TODO(molson): Make a config/setting
        conn.options.timeout = 15       # TODO(molson): Make a config/setting
        conn.request :soap_headers
        conn.response :soap_parser
        # conn.request(:curl, ::Logger.new(STDOUT), :warn)
        conn.use :breakers
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
