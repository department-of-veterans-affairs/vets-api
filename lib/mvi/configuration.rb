# frozen_string_literal: true
require 'common/client/configuration/soap'

module MVI
  class Configuration < Common::Client::Configuration::SOAP
    # :nocov:
    def self.default_mvi_open_timeout
      Rails.logger.warn 'MVI_OPEN_TIMEOUT env variable not set, using default'
      2
    end

    def self.default_mvi_timeout
      Rails.logger.warn 'MVI_TIMEOUT env variable not set, using default'
      10
    end
    # :nocov:

    URL = ENV['MVI_URL']
    OPEN_TIMEOUT = ENV['MVI_OPEN_TIMEOUT']&.to_i || default_mvi_open_timeout
    TIMEOUT = ENV['MVI_TIMEOUT']&.to_i || default_mvi_timeout

    SSL_CERT = begin
      OpenSSL::X509::Certificate.new(File.read(ENV['MVI_CLIENT_CERT_PATH']))
    rescue => e
      # :nocov:
      Rails.logger.warn "Could not load MVI SSL cert: #{e.message}"
      raise e if Rails.env.production?
      nil
      # :nocov:
    end

    SSL_KEY = begin
      OpenSSL::PKey::RSA.new(File.read(ENV['MVI_CLIENT_KEY_PATH']))
    rescue => e
      # :nocov:
      Rails.logger.warn "Could not load MVI SSL key: #{e.message}"
      raise e if Rails.env.production?
      nil
      # :nocov:
    end

    def base_path
      ENV['MVI_URL']
    end

    def service_name
      'MVI'
    end

    def ssl_options
      if MVI::Configuration::SSL_CERT && MVI::Configuration::SSL_KEY
        {
          client_cert: MVI::Configuration::SSL_CERT,
          client_key: MVI::Configuration::SSL_KEY
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
