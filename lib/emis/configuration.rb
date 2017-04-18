# frozen_string_literal: true
require 'common/client/configuration/soap'

module EMIS
  class Configuration < Common::Client::Configuration::SOAP
    SSL_CERT = begin
      OpenSSL::X509::Certificate.new(File.read(Settings.emis.client_cert_path))
    rescue => e
      # :nocov:
      Rails.logger.warn "Could not load EMIS SSL cert: #{e.message}"
      raise e if Rails.env.production?
      nil
      # :nocov:
    end

    SSL_KEY = begin
      OpenSSL::PKey::RSA.new(File.read(Settings.emis.client_key_path))
    rescue => e
      # :nocov:
      Rails.logger.warn "Could not load EMIS SSL key: #{e.message}"
      raise e if Rails.env.production?
      nil
      # :nocov:
    end

    def ssl_options
      if EMIS::Configuration::SSL_CERT && EMIS::Configuration::SSL_KEY
        {
          client_cert: EMIS::Configuration::SSL_CERT,
          client_key: EMIS::Configuration::SSL_KEY
        }
      end
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options, ssl: ssl_options) do |conn|
        conn.request :soap_headers
        conn.response :soap_parser
        conn.use :breakers
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
