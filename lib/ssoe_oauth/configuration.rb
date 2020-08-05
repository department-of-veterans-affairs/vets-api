# frozen_string_literal: true

require 'common/client/configuration/rest'

module SSOeOAuth
  # Configuration for the SSOeOAuth::Service. A singleton class that returns
  # a connection that can make signed requests
  #
  # @example set the configuration in the service
  #   configuration SSOeOAuth::Configuration
  #
  class Configuration < Common::Client::Configuration::REST
    include Common::Client::Configuration::Concerns::Ssl

    def self.ssl_cert_path
      Settings.ssoe_auth.client_cert_path
    end

    def self.ssl_key_path
      Settings.ssoe_auth.client_key_path
    end

    def base_path
      Settings.ssoe_auth.url
    end

    def service_name
      'SSOeOAuth'
    end

    def connection
      @connection ||= Faraday.new(
        base_path, headers: base_request_headers, request: request_options, ssl: ssl_options
      ) do |conn|
        conn.use :breakers
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
