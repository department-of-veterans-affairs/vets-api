# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'rx/client'
require 'mobile/v0/prescriptions/configuration'
require 'mobile/v0/prescriptions/client_session'

module Mobile
  module V0
    module Prescriptions
      ##
      # Class responsible for Rx API interface operations
      # Overrides configuration class member to use mobile-specific token
      #
      class Client < Rx::Client
        configuration Mobile::V0::Prescriptions::Configuration
        client_session Mobile::V0::Prescriptions::ClientSession
      end
    end
  end
end
