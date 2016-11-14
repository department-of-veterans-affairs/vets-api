# frozen_string_literal: true
require 'faraday'
require 'multi_json'
require 'common/client/errors'
require 'common/client/concerns/client_methods'
require 'common/client/concerns/mhv_session_based_client'
require 'common/client/middleware/request/camelcase'
require 'common/client/middleware/request/multipart_request'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'
require 'sm/middleware/response/sm_parser'
require 'sm/client_session'
require 'sm/configuration'
require 'sm/api/sessions'
require 'sm/api/triage_teams'
require 'sm/api/folders'
require 'sm/api/messages'
require 'sm/api/message_drafts'

module SM
  class Client
    include Common::Client::MHVSessionBasedClient
    include SM::API::Sessions
    include SM::API::TriageTeams
    include SM::API::Folders
    include SM::API::Messages
    include SM::API::MessageDrafts

    def connection
      @connection ||= Faraday.new(config.base_path, headers: config.base_request_headers, request: config.request_options) do |conn|
        conn.use :breakers
        conn.request :camelcase
        conn.request :multipart_request
        conn.request :multipart
        conn.request :json
        # Uncomment this out for generating curl output to send to MHV dev and test only
        # conn.request :curl, ::Logger.new(STDOUT), :warn

        # conn.response :logger, ::Logger.new(STDOUT), bodies: true
        conn.response :sm_parser
        conn.response :snakecase
        conn.response :raise_error
        conn.response :json_parser

        conn.adapter Faraday.default_adapter
      end
    end
  end
end
