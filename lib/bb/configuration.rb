# frozen_string_literal: true
require 'common/client/configuration/rest'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/snakecase'
require 'bb/middleware/response/bb_parser'

module BB
  # Configuration class used to setup the environment used by client
  class Configuration < Common::Client::Configuration::REST
    def app_token
      ENV['MHV_APP_TOKEN']
    end

    def base_path
      "#{ENV['MHV_HOST']}/mhv-api/patient/v1/"
    end

    def service_name
      'BB'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        verbose_logging = false

        conn.use :breakers
        conn.request :camelcase
        conn.request :json

        # NOTE: To avoid having PII accidentally logged, only change the verbose_flag up above
        if !Rails.env.production? && verbose_logging
          # generating curl output to send to MHV dev and test only
          conn.request :curl, ::Logger.new(STDOUT), :warn
          # logs a verbose response including body
          conn.response :logger, ::Logger.new(STDOUT), bodies: true
        end

        conn.response :bb_parser
        conn.response :snakecase
        conn.response :raise_error, error_prefix: service_name
        conn.response :mhv_errors
        conn.response :json_parser

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
