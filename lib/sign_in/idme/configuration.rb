# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/logging'

module SignIn::Idme
  class Configuration < Common::Client::Configuration::REST
    def base_path
      Settings.idme.oauth_url
    end

    def client_id
      Settings.idme.client_id
    end

    def client_secret
      Settings.idme.client_secret
    end

    def redirect_uri
      Settings.idme.redirect_uri
    end

    def client_key_path
      Settings.idme.client_key_path
    end

    def client_cert_path
      Settings.idme.client_cert_path
    end

    def service_name
      'idme'
    end

    def dslogon_scope
      'dslogon_loa3'
    end

    def mhv_scope
      'myhealthevet_loa3'
    end

    def idme_scope
      LOA::IDME_LOA3
    end

    def auth_path
      'oauth/authorize'
    end

    def token_path
      'oauth/token'
    end

    def userinfo_path
      'api/public/v3/userinfo.json'
    end

    def client_assertion_type
      'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
    end

    def grant_type
      'authorization_code'
    end

    def client_assertion_expiration_seconds
      1000
    end

    def response_type
      'code'
    end

    def ssl_key
      OpenSSL::PKey::RSA.new(File.read(client_key_path))
    end

    def ssl_cert
      OpenSSL::X509::Certificate.new(File.read(client_cert_path))
    end

    # Faraday connection object with breakers, snakecase and json response middleware
    # @return Faraday::Connection connection to make http calls
    #
    def connection
      @connection ||= Faraday.new(
        base_path,
        headers: base_request_headers,
        request: request_options,
        ssl: { client_cert: ssl_cert,
               client_key: ssl_key }
      ) do |conn|
        conn.use :breakers
        conn.use Faraday::Response::RaiseError
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
