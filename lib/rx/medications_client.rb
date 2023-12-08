# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'rx/configuration'
require 'rx/client_session'
require 'rx/rx_gateway_timeout'
require 'active_support/core_ext/hash/slice'

module Rx
  ##
  # Core class responsible for Rx API interface operations on va.gov
  #
  class MedicationsClient < Rx::Client
    include Common::Client::Concerns::MHVSessionBasedClient
    configuration Rx::Configuration
    client_session Rx::ClientSession

    def auth_headers
      config.base_request_headers.merge('appToken' =>
        config.app_token_va_gov, 'mhvCorrelationId' => session.user_id.to_s)
    end
  end
end
