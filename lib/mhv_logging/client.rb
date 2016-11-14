# frozen_string_literal: true
require 'faraday'
require 'common/client/errors'
require 'common/client/concerns/client_methods'
require 'common/client/concerns/session_based_client'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'
require 'mhv_logging/api/audits'
require 'rx/api/sessions'
require 'rx/configuration'
require 'rx/client_session'

# NOTE: This client uses the exact same configuration, breakers, and client session
# as Rx does. It is the same server, but we're building it as a separate client
# for better separation of concerns since it can be invoked when using secure messaging

module MHVLogging
  # Core class responsible for api interface operations
  class Client
    include Common::ClientMethods
    include Common::SessionBasedClient
    include MHVLogging::API::Audits
    include Rx::API::Sessions

    def initialize(session:)
      @config = Rx::Configuration.instance
      @session = Rx::ClientSession.find_or_build(session)
    end

    def connection
      @connection ||= Faraday.new(config.base_path, headers: config.base_request_headers, request: config.request_options) do |conn|
        conn.use :breakers
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
