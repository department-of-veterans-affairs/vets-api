# frozen_string_literal: true
require 'evss/error_middleware'

module EVSS
  class BaseService
    SYSTEM_NAME = 'vets.gov'
    DEFAULT_TIMEOUT = 15 # in seconds

    def initialize(headers)
      @headers = headers
    end

    # :nocov:
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
    # :nocov:

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

    private

    # Uses HTTPClient adapter because headers need to be sent unmanipulated
    # Net/HTTP capitalizes headers
    def conn
      @conn ||= Faraday.new(base_url, headers: @headers, ssl: ssl_options) do |faraday|
        faraday.options.timeout = DEFAULT_TIMEOUT
        faraday.use      :breakers
        faraday.use      EVSS::ErrorMiddleware
        faraday.use      Faraday::Response::RaiseError
        faraday.response :json, content_type: /\bjson$/
        faraday.adapter  :httpclient
      end
    end

    def ssl_options
      {
        version: :TLSv1_2,
        verify: true,
        client_cert: client_cert,
        client_key: client_key,
        ca_file: root_ca
      } if cert?
    end

    def cert?
      ENV['EVSS_CERT_FILE_PATH'].present? ||
        ENV['EVSS_CERT_KEY_PATH'].present? ||
        ENV['EVSS_ROOT_CERT_FILE_PATH'].present?
    end

    # :nocov:
    def client_cert
      OpenSSL::X509::Certificate.new File.read(ENV['EVSS_CERT_FILE_PATH'])
    end

    def client_key
      OpenSSL::PKey::RSA.new File.read(ENV['EVSS_CERT_KEY_PATH'])
    end

    def root_ca
      ENV['EVSS_ROOT_CERT_FILE_PATH']
    end
    # :nocov:
  end
end
