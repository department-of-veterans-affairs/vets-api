# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/snakecase'
require 'common/client/middleware/response/mhv_xml_html_errors'
require 'bb/middleware/response/bb_parser'

module BB
  # Configuration class used to setup the environment used by client
  class Configuration < Common::Client::Configuration::REST
    def app_token
      Settings.mhv.rx.app_token
    end

    def base_path
      "#{Settings.mhv.rx.host}/mhv-api/patient/v1/"
    end

    def caching_enabled?
      Settings.mhv.bb.collection_caching_enabled || false
    end

    def service_name
      'BB'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.request :camelcase
        conn.request :json

        # Uncomment this if you want curl command equivalent or response output to log
        # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
        # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

        conn.response :betamocks if Settings.mhv.bb.mock
        conn.response :bb_parser
        conn.response :snakecase
        conn.response :raise_error, error_prefix: service_name, exception_class: service_exception
        conn.response :mhv_errors
        conn.response :mhv_xml_html_errors, exception_class: service_exception
        conn.response :json_parser

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
