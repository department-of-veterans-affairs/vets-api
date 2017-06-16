# frozen_string_literal: true
require 'evss/error_middleware'

module EVSS
  class BaseService
    SYSTEM_NAME = 'vets.gov'
    DEFAULT_TIMEOUT = 15 # in seconds

    def initialize(headers)
      @headers = headers
    end

    def self.create_breakers_service(name:, url:)
      path = URI.parse(url).path
      host = URI.parse(url).host
      matcher = proc do |request_env|
        request_env.url.host == host && request_env.url.path =~ /^#{path}/
      end

      Breakers::Service.new(
        name: name,
        request_matcher: matcher
      )
    end

    protected

    def get(url)
      conn.get url
    end

    def post(url, body = nil, headers = { 'Content-Type' => 'application/json' }, &block)
      conn.post(url, body, headers, &block)
    end

    def base_url
      self.class::BASE_URL
    end

    def timeout
      self.class::DEFAULT_TIMEOUT
    end

    private

    # Uses HTTPClient adapter because headers need to be sent unmanipulated
    # Net/HTTP capitalizes headers
    def conn
      @conn ||= Faraday.new(base_url, headers: @headers, ssl: ssl_options) do |faraday|
        faraday.options.timeout = timeout
        faraday.use      :breakers
        faraday.use      EVSS::ErrorMiddleware
        faraday.use      Faraday::Response::RaiseError
        faraday.response :snakecase, symbolize: false
        faraday.response :json
        faraday.adapter  :httpclient
      end
    end

    def ssl_options
      return { verify: false } #if !cert? && Rails.env.development?
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
  end
end
