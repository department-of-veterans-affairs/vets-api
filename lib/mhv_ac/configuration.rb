# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_custom_error'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/mhv_xml_html_errors'
require 'common/client/middleware/response/snakecase'

module MHVAC
  ##
  # HTTP client configuration for the {MHVAC::Client}, sets the token, base path and a service name for
  # breakers and metrics
  #
  class Configuration < Common::Client::Configuration::REST
    ##
    # @return [String] Client token set in `settings.yml` via credstash
    #
    def app_token
      Settings.mhv.rx.app_token
    end

    ##
    # @return [String] API GW key set in `settings.yml` via credstash
    #
    def x_api_key
      Settings.mhv.rx.x_api_key
    end

    ##
    # @return [String] Base path for dependent URLs
    #
    def base_path
      if Flipper.enabled?(:mhv_medications_migrate_to_api_gateway)
        "#{Settings.mhv.api_gateway.hosts.pharmacy}/#{Settings.mhv.rx.gw_base_path}"
      else
        "#{Settings.mhv.rx.host}/#{Settings.mhv.rx.base_path}"
      end
    rescue NoMethodError => e
      Rails.logger.error("RX:Configuration Flipper error: #{e.message}")
      "#{Settings.mhv.rx.host}/#{Settings.mhv.rx.base_path}" # Default path
    end

    ##
    # @return [String] Service name to use in breakers and metrics
    #
    def service_name
      'MHVAcctCreation'
    end

    ##
    # Creates a connection with middleware for mapping errors, parsing XML, and
    # adding breakers functionality
    #
    # @return [Faraday::Connection] a Faraday connection instance
    #
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :camelcase
        conn.request :json

        # Uncomment this if you want curl command equivalent or response output to log
        # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
        # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

        conn.response :snakecase
        conn.response :raise_custom_error, error_prefix: service_name
        conn.response :mhv_errors
        conn.response :mhv_xml_html_errors
        conn.response :json_parser
        conn.response :betamocks if Settings.mhv.account.mock

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
