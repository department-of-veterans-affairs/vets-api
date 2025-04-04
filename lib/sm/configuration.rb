# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/request/multipart_request'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_custom_error'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/snakecase'
require 'faraday/multipart'
require 'sm/middleware/response/sm_parser'

module SM
  ##
  # HTTP client configuration for {SM::Client}, sets the token, base path and a service name for breakers and metrics
  #
  class Configuration < Common::Client::Configuration::REST
    ##
    # @return [String] Client token set in `settings.yml` via credstash
    #
    def app_token
      Settings.mhv.sm.app_token
    end

    ##
    # @return [String] Base path for dependent URLs
    #
    def base_path
      "#{Settings.mhv.sm.host}/mhv-sm-api/patient/v1/"
    end

    ##
    # @return [String] Service name to use in breakers and metrics
    #
    def service_name
      'SM'
    end

    ##
    # Creates a connection with middleware for mapping errors, parsing XML, and
    # adding breakers functionality
    #
    # @see SM::Middleware::Response::SMParser
    # @return [Faraday::Connection] a Faraday connection instance
    #
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :camelcase
        conn.request :multipart_request
        conn.request :multipart
        conn.request :json

        # Uncomment this if you want curl command equivalent or response output to log
        # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
        # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

        conn.response :betamocks if Settings.mhv.sm.mock
        conn.response :sm_parser
        conn.response :snakecase
        conn.response :raise_custom_error, error_prefix: service_name
        conn.response :mhv_errors
        conn.response :mhv_xml_html_errors
        conn.response :json_parser

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
