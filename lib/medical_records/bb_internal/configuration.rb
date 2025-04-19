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

module BBInternal
  ##
  # HTTP client configuration for {PHRMgr::Client}
  #
  class Configuration < Common::Client::Configuration::REST
    ##
    # Setter for thread-local variable custom_base_path
    #
    def self.custom_base_path=(value)
      Thread.current[:custom_base_path] = value
    end

    ##
    # Getter for thread-local variable custom_base_path
    #
    def self.custom_base_path
      Thread.current[:custom_base_path]
    end

    ##
    # BB Internal uses the same app token as Rx.
    # @return [String] Client token set in `settings.yml` via credstash
    #
    def app_token
      Settings.mhv.rx.app_token
    end

    def x_api_key
      Settings.mhv.medical_records.x_api_key
    end

    ##
    # BB Internal uses the same domain as Medical Records FHIR.
    # @return [String] Base path for dependent URLs
    #
    def base_path
      if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway)
        self.class.custom_base_path || "#{Settings.mhv.api_gateway.hosts.bluebutton}/v1/"
      else
        "#{Settings.mhv.medical_records.host}/mhvapi/v1/"
      end
    end

    ##
    # @return [String] Service name to use in breakers and metrics
    #
    def service_name
      'BBInternal'
    end

    COMMON_STACK = lambda do |conn, service_name|
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
    end

    ##
    # @return [Faraday::Connection] a Faraday connection instance
    #
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        COMMON_STACK.call(conn, service_name)
        conn.adapter Faraday.default_adapter
      end
    end

    ##
    # @return [Faraday::Connection] a Faraday connection instance supporting parallel requests
    #
    def parallel_connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        COMMON_STACK.call(conn, service_name)
        conn.adapter :typhoeus
      end
    end
  end
end
