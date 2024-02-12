# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/request/multipart_request'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/snakecase'
require 'sm/middleware/response/sm_parser'

module MedicalRecords
  ##
  # HTTP client configuration for {MedicalRecords::Client}
  #
  class Configuration < Common::Client::Configuration::REST
    ##
    # @return [String] Client token set in `settings.yml` via credstash
    #
    def app_token
      Settings.mhv.medical_records.app_token
    end

    ##
    # @return [String] Base path for dependent URLs
    #
    def base_path
      Settings.mhv.medical_records.host
    end

    ##
    # @return [String] Service name to use in breakers and metrics
    #
    def service_name
      'MedicalRecords'
    end

    ##
    # Creates a connection
    #
    # @return [Faraday::Connection] a Faraday connection instance
    #
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.request :multipart_request
        conn.request :multipart
        conn.request :json

        # Uncomment this if you want curl command equivalent or response output to log
        # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
        # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

        # conn.response :betamocks if Settings.mhv.sm.mock
        conn.response :snakecase
        conn.response :raise_error, error_prefix: service_name
        conn.response :mhv_errors
        conn.response :mhv_xml_html_errors
        conn.response :json_parser
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
