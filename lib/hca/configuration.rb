# frozen_string_literal: true
require 'common/client/configuration'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'

module HCA
  # Configuration class used to setup the environment used by client
  class Configuration < Common::Client::Configuration
    def base_path
      # setup your base path here as a string
    end

    def base_request_headers
      super.merge(additional_header_attributes)
    end

    def additional_header_attributes
      {} # add additional header attributes if necessary or remove this and the above methods
    end

    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.request :json
        # Uncomment this out for generating curl output to send to MHV dev and test only
        # conn.request :curl, ::Logger.new(STDOUT), :warn

        # conn.response :logger, ::Logger.new(STDOUT), bodies: true
        conn.response :raise_error
        conn.response :json_parser

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
