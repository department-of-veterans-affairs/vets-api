# frozen_string_literal: true
require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'mhv_logging/api/audits'
require 'rx/configuration'
require 'rx/client_session'

# NOTE: This client uses the exact same configuration and client session
# as Rx does. It is the same server, but we're building it as a separate client
# for better separation of concerns since it can be invoked when using secure messaging

module MHVLogging
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient
    include MHVLogging::API::Audits

    configuration Rx::Configuration
    client_session Rx::ClientSession

    private

    # Override connection in superclass because we don't want breakers for this client
    def connection
      @connection ||=
        Faraday.new(config.base_path, headers: config.base_request_headers, request: config.request_options) do |conn|
          conn.request :json
          # Uncomment this out for generating curl output to send to MHV dev and test only
          # conn.request :curl, ::Logger.new(STDOUT), :warn

          # conn.response :logger, ::Logger.new(STDOUT), bodies: true
          conn.response :snakecase
          conn.response :raise_error
          conn.response :json_parser
          conn.adapter Faraday.default_adapter
        end
    end
  end
end
