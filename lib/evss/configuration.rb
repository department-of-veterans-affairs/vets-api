# frozen_string_literal: true
require 'common/client/configuration/rest'

module EVSS
  class Configuration < Common::Client::Configuration::REST
    # :nocov:
    def client_cert
      OpenSSL::X509::Certificate.new File.read(Settings.evss.cert_path)
    end

    def client_key
      OpenSSL::PKey::RSA.new File.read(Settings.evss.key_path)
    end

    def root_ca
      Settings.evss.root_cert_path
    end
    # :nocov:

    def ssl_options
      return { verify: false } if !cert? && (Rails.env.development? || Rails.env.test?)
      {
        version: :TLSv1_2,
        verify: true,
        client_cert: client_cert,
        client_key: client_key,
        ca_file: root_ca
      } if cert?
    end

    def cert?
      # TODO(knkski): Is this logic correct?
      Settings.evss.cert_path.present? ||
        Settings.evss.key_path.present? ||
        Settings.evss.root_cert_path.present?
    end

    def connection
      @conn ||= Faraday.new(base_path, request: request_options, ssl: ssl_options) do |faraday|
        faraday.use      :breakers
        faraday.use      EVSS::ErrorMiddleware
        faraday.use      Faraday::Response::RaiseError
        faraday.response :betamocks if mock_enabled?
        faraday.response :snakecase, symbolize: false
        # calls to EVSS returns non JSON responses for some scenarios that don't make it through VAAFI
        # content_type: /\bjson$/ ensures only json content types are attempted to be parsed.
        faraday.response :json, content_type: /\bjson$/
        faraday.use :immutable_headers
        faraday.adapter Faraday.default_adapter
      end
    end

    def mock_enabled?
      # sublcass to override
      false
    end
  end
end
