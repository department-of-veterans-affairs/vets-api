# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/snakecase'
require 'faraday/multipart'

module Ccra
  # CCRA::Configuration provides the configuration settings for the CCRA API.
  # It retrieves settings from the application configuration (e.g., Settings.vaos.ccra)
  # and delegates common REST parameters.
  class Configuration < Common::Client::Configuration::REST
    delegate :access_token_url, :api_url, :base_path, :grant_type, :scopes, :client_assertion_type, to: :settings

    ##
    # Returns the settings for the CCRA service.
    #
    # This is typically loaded from a configuration initializer or YAML file.
    #
    # @return [Hash, OpenStruct] The CCRA settings from Settings.vaos.ccra.
    def settings
      Settings.vaos.ccra
    end

    ##
    # Returns the name of the service.
    #
    # @return [String] The service name, which in this case is "CCRA".
    def service_name
      'CCRA'
    end

    ##
    # Indicates whether mock responses are enabled for the CCRA service.
    #
    # @return [Boolean] True if mock responses are enabled; otherwise false.
    def mock_enabled?
      settings.mock
    end

    ##
    # Creates and returns a Faraday connection configured for the CCRA API.
    #
    # @return [Faraday::Connection] A configured Faraday connection object.
    def connection
      Faraday.new(api_url, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :camelcase
        conn.request :json

        if ENV['VAOS_CCRA_DEBUG'] && !Rails.env.production?
          conn.request(:curl, ::Logger.new($stdout), :warn)
          conn.response(:logger, ::Logger.new($stdout), bodies: true)
        end

        conn.response :betamocks if mock_enabled?
        conn.response :snakecase
        conn.response :json
        conn.response :vaos_errors
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
