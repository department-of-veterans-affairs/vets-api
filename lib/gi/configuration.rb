# frozen_string_literal: true
require 'common/client/configuration/rest'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'

module GI
  # Configuration class used to setup the environment used by client
  class Configuration < Common::Client::Configuration::REST
    def base_path
      "#{ENV['GIDS_HOST']}/v0/"
    end

    def service_name
      'GI'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.use Faraday::Request::BasicAuthentication, ENV['GIDS_USER'], ENV['GIDS_PASS']
        conn.request :json
        # Uncomment this out for generating curl output to send to MHV dev and test only
         conn.request :curl, ::Logger.new(STDOUT), :warn

         conn.response :logger, ::Logger.new(STDOUT), bodies: true
        conn.response :snakecase
        conn.response :raise_error, error_prefix: service_name
        conn.response :json_parser

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
