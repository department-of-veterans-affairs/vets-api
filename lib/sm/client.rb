# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
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
