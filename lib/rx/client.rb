# frozen_string_literal: true
require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'rx/configuration'
require 'rx/client_session'
require 'rx/api/prescriptions'
require 'rx/api/sessions'

module Rx
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    include Common::Client::MHVSessionBasedClient
    include Rx::API::Prescriptions
    include Rx::API::Sessions

    configuration Rx::Configuration
    client_session Rx::ClientSession
  end
end
