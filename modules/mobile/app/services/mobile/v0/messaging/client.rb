# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'sm/client'
require 'mobile/v0/messaging/client_session'
require 'mobile/v0/messaging/configuration'

module Mobile
  module V0
    module Messaging
      ##
      # Class responsible for SM API interface operations
      # Overrides configuration class member to use mobile-specific token
      # Overrides client_session class member to use mobile-specific
      #  session cache
      #
      class Client < SM::Client
        configuration Mobile::V0::Messaging::Configuration
        client_session Mobile::V0::Messaging::ClientSession
      end
    end
  end
end
