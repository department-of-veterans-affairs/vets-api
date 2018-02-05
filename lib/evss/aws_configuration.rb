# frozen_string_literal: true

module EVSS
  class AWSConfiguration < Common::Client::Configuration::REST
    extend Memoist

    def mock_enabled?
      # subclass to override
      false
    end

    # :nocov:
    def client_cert
      OpenSSL::X509::Certificate.new File.read(Settings.evss.aws.cert_path)
    end

    def client_key
      OpenSSL::PKey::RSA.new File.read(Settings.evss.aws.key_path)
    end

    def root_ca
      Settings.evss.aws.root_ca
    end
    # :nocov:

    def ssl_options
      return { verify: false } if !cert? && (Rails.env.development? || Rails.env.test?)
      if cert?
        {
          version: :TLSv1_2,
          verify: true,
          client_cert: client_cert,
          client_key: client_key,
          ca_file: root_ca
        }
      end
    end

    def cert?
      Settings.evss.cert_path.present? ||
        Settings.evss.key_path.present? ||
        Settings.evss.root_cert_path.present?
    end

    def connection
      req_options = Settings.faraday_socks_proxy.enabled ? request_options.merge(proxy_options) : request_options
      @conn ||= Faraday.new(base_path, request: req_options, ssl: ssl_options) do |faraday|
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

    protected

    def proxy_options
      {
        proxy: {
          uri:  URI.parse(Settings.faraday_socks_proxy.uri),
          socks: Settings.faraday_socks_proxy.enabled
        }
      }
    end
    memoize :proxy_options
  end
end
