# frozen_string_literal: true
require 'common/client/configuration/soap'

module HCA
  class Configuration < Common::Client::Configuration::SOAP
    CONFIG = Rails.application.config_for(:health_care_application).freeze

    def self.cert_store(paths)
      store = OpenSSL::X509::Store.new
      Array(paths).each do |path|
        store.add_file(Rails.root.join('config', 'health_care_application', 'certs', path).to_s)
      end
      store
    end

    HEALTH_CHECK_ID = 377_609_264
    WSDL = Rails.root.join('config', 'health_care_application', 'wsdl', 'voa.wsdl')
    CERT_STORE = (cert_store(CONFIG['ca']) if CONFIG['ca'])

    SSL_CERT = begin
      OpenSSL::X509::Certificate.new(File.read(ENV['ES_CLIENT_CERT_PATH']))
    rescue => e
      # :nocov:
      Rails.logger.warn "Could not load ES SSL cert: #{e.message}"
      raise e if Rails.env.production?
      nil
      # :nocov:
    end

    SSL_KEY = begin
      OpenSSL::PKey::RSA.new(File.read(ENV['ES_CLIENT_KEY_PATH']))
    rescue => e
      # :nocov:
      Rails.logger.warn "Could not load ES SSL key: #{e.message}"
      raise e if Rails.env.production?
      nil
      # :nocov:
    end

    def base_path
      CONFIG['endpoint']
    end

    def service_name
      'HCA'
    end

    def ssl_options
      ssl = {
        verify: true
      }
      if HCA::Configuration::CERT_STORE
        ssl[:cert_store] = HCA::Configuration::CERT_STORE
      end
      if HCA::Configuration::SSL_CERT && HCA::Configuration::SSL_KEY
        ssl.merge!(client_cert: HCA::Configuration::SSL_CERT, client_key: HCA::Configuration::SSL_KEY)
      end
      ssl
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options, ssl: ssl_options) do |conn|
        conn.options.open_timeout = 10  # TODO(molson): Make a config/setting
        conn.options.timeout = 15       # TODO(molson): Make a config/setting
        conn.request :soap_headers
        conn.response :soap_parser
        conn.use :breakers
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
