# frozen_string_literal: true
require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'

module AppealsStatus
  # Configuration class used to setup the environment used by client
  class Configuration < Common::Client::Configuration::REST
    def app_token
      Settings.appeals_status.app_token
    end

    def base_path
      "#{Settings.appeals_status.host}/api/v1/appeals"
    end

    def service_name
      'AppealsStatus'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options, ssl: { verify: false }) do |conn|
        conn.use :breakers
        conn.request :json

        # Uncomment this if you want curl command equivalent or response output to log
        # conn.request(:curl, ::Logger.new(STDOUT), :warn) unless Rails.env.production?
        # conn.response(:logger, ::Logger.new(STDOUT), bodies: true) unless Rails.env.production?

        conn.response :snakecase
        conn.response :raise_error, error_prefix: service_name
        conn.response :json_parser
        conn.adapter Faraday.default_adapter
      end
    end
  end
end
