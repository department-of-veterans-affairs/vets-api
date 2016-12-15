# frozen_string_literal: true
require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'bb/configuration'
require 'bb/client_session'

module BB
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient

    configuration BB::Configuration
    client_session BB::ClientSession
  end
end
