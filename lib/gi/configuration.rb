# frozen_string_literal: true
require 'common/client/configuration/rest'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'
require 'gi/middleware/response/link_transformer'

module Gi
  # Configuration class used to setup the environment used by client
  class Configuration < Common::Client::Configuration::REST

    def base_path
      "#{ENV['GIDS_HOST']}/v0/"
    end

    def service_name
      'Gi'
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use :breakers
        conn.request :json

        conn.response :logger, ::Logger.new(STDOUT), bodies: true # todo: rm this
        conn.response :snakecase
        conn.response :raise_error, error_prefix: service_name
        conn.response :json_parser
        conn.response :link_transformer

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
