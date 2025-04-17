# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/response/gids_errors'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_custom_error'
require 'common/client/middleware/response/snakecase'

module GI
  class Configuration < Common::Client::Configuration::REST
    self.read_timeout = Settings.gids.read_timeout || 1
    self.open_timeout = Settings.gids.open_timeout || 1

    def base_path
      "#{Settings.gids.url}/"
    end

    def service_name
      'GI'
    end

    def connection
      Faraday.new(base_path, headers: request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :json
        # Uncomment this out for generating curl output
        # conn.request :curl, ::Logger.new(STDOUT), :warn

        # conn.response :logger, ::Logger.new(STDOUT), bodies: true
        conn.response :snakecase
        conn.response :raise_custom_error, error_prefix: service_name, allow_not_modified: versioning_enabled?
        conn.response :gids_errors
        conn.response :json_parser

        conn.adapter Faraday.default_adapter
      end
    end

    private

    def request_headers
      base_request_headers
    end

    def versioning_enabled?
      try(:etag).present?
    end
  end
end
