# frozen_string_literal: true

require 'common/client/configuration/base'

module SSOe
  class Configuration < Common::Client::Configuration::SOAP
    def service_name
      'SSOe Get Traits'
    end

    def connection
      @connection ||= Faraday.new(base_path, headers: base_request_headers, request: request_options,
                                             ssl: ssl_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :soap_headers
        conn.response :soap_parser
        conn.response :betamocks if IdentitySettings.ssoe_get_traits.mock
        conn.adapter Faraday.default_adapter
      end
    end

    private

    def ssl_options
      {
        client_cert: ssl_cert,
        client_key: ssl_key
      }
    rescue OpenSSL::OpenSSLError, Errno::ENOENT => e
      Rails.logger.error("[SSOe::Configuration] SSL error: #{e.message}")
      raise
    end

    def ssl_cert
      OpenSSL::X509::Certificate.new(File.read(IdentitySettings.ssoe_get_traits.client_cert_path))
    end

    def ssl_key
      OpenSSL::PKey::RSA.new(File.read(IdentitySettings.ssoe_get_traits.client_key_path))
    end

    def base_path
      IdentitySettings.ssoe_get_traits.url
    end
  end
end
