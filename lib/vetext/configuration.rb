# frozen_string_literal: true

require 'common/client/configuration/rest'

module VEText
  # Configuration for the VEText::Service. A singleton class that returns
  # a connection that can make requests
  #
  # @example set the configuration in the service
  #   configuration VEText::Configuration
  #
  class Configuration < Common::Client::Configuration::REST

    # Override the parent's base path
    # @return String the service base path from the environment settings
    #
    def base_url
      Settings.vetext_push.base_url
    end

    # Service name for breakers integration
    # @return String the service name
    #
    def service_name
      'VEText'
    end

    # Faraday connection object with breakers, snakecase and json response middleware
    # @return Faraday::Connection connection to make http calls
    #
    def connection
      @connection ||= Faraday.new(
        base_url, headers: base_request_headers, request: request_options
      ) do |conn|
        conn.basic_auth(Settings.vetext_push.user, Settings.vetext_push.pass)
        conn.use :breakers
        conn.request :json
        
        conn.use Faraday::Response::RaiseError
        conn.response :snakecase
        conn.response :json, content_type: /\bjson$/
        conn.adapter Faraday.default_adapter
      end
    end

  end
end
