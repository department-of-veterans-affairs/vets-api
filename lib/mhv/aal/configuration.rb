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

module AAL
  class Configuration < Common::Client::Configuration::REST
    def base_path
      if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway)
        "#{Settings.mhv.api_gateway.hosts.usermgmt}/v1/"
      else
        "#{Settings.mhv.medical_records.host}/mhvapi/v1/"
      end
    end

    ##
    # @return [String] Service name to use in breakers and metrics
    #
    def service_name
      'AAL'
    end

    ##
    # @return [Faraday::Connection] a Faraday connection instance
    #
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :multipart_request
        conn.request :multipart
        conn.request :camelcase
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

  class MRConfiguration < Configuration
    def app_token
      Settings.mhv.medical_records.app_token
    end

    def x_api_key
      Settings.mhv.medical_records.x_api_key
    end
  end

  class RXConfiguration < Configuration
    def app_token
      Settings.mhv.rx.app_token
    end

    def x_api_key
      Settings.mhv.rx.x_api_key
    end
  end

  class SMConfiguration < Configuration
    def app_token
      Settings.mhv.sm.app_token
    end

    def x_api_key
      Settings.mhv.sm.x_api_key
    end
  end
end
