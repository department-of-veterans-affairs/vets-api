# frozen_string_literal: true

require 'common/client/base'
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
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient
    include SM::API::Sessions
    include SM::API::TriageTeams
    include SM::API::Folders
    include SM::API::Messages
    include SM::API::MessageDrafts

    configuration SM::Configuration
    client_session SM::ClientSession
  end
end
