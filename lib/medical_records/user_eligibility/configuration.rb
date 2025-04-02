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

module UserEligibility
  ##
  # HTTP client configuration for {UserEligibility::Client}
  #
  class Configuration < Common::Client::Configuration::REST
    ##
    # @return [String] Base path for dependent URLs
    #
    def base_path
      "#{Settings.mhv.medical_records.host}/v1/usermgmt/usereligibility/"
    end

    ##
    # @return [Hash] Headers with x-api-key and RX appToken header values for dependent URLs
    #
    def x_headers
      base_request_headers.merge({
                                   'x-api-key': Settings.mhv.medical_records.x_api_key,
                                   appToken: Settings.mhv.rx.app_token
                                 })
    end

    ##
    # @return [String] Service name to use in breakers and metrics
    #
    def service_name
      'UserEligibility'
    end

    ##
    # Creates a connection
    #
    # @return [Faraday::Connection] a Faraday connection instance
    #
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :multipart_request
        conn.request :multipart
        conn.request :json

        # Uncomment this if you want curl command equivalent or response output to log
        # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
        # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

        conn.response :raise_custom_error, error_prefix: service_name
        conn.response :mhv_errors
        conn.response :mhv_xml_html_errors
        conn.response :json_parser
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
