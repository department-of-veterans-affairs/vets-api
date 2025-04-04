# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_custom_error'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/snakecase'
require 'common/client/middleware/response/mhv_xml_html_errors'
require 'bb/middleware/response/bb_parser'

module BB
  ##
  # HTTP client configuration for {BB::Client}, sets the token, base path and a service name for breakers and metrics
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
    # @return [String] Client token set in `settings.yml` via credstash
    #
    def app_token
      Settings.mhv.rx.app_token
    end

    def x_api_key
      Settings.mhv.medical_records.x_api_key
    end

    ##
    # @return [String] Base path for dependent URLs
    #
    def base_path
      # We can't use Flipper in this class due to a race condition with Breakers. So we will set
      # the path in the client and use a thread-local variable here.
      self.class.custom_base_path || "#{Settings.mhv.rx.host}/mhv-api/patient/v1/"
    end

    ##
    # @return [Boolean] if the MHV BB collections should be cached
    #
    def caching_enabled?
      Settings.mhv.bb.collection_caching_enabled || false
    end

    ##
    # @return [String] Service name to use in breakers and metrics
    #
    def service_name
      'BB'
    end

    ##
    # Creates a connection with middleware for mapping errors, parsing XML, and
    # adding breakers functionality
    #
    # @see BB::Middleware::Response::BBParser
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

        conn.response :betamocks if Settings.mhv.bb.mock
        conn.response :bb_parser
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
