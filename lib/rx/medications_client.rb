# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'rx/configuration'
require 'rx/client_session'
require 'rx/rx_gateway_timeout'
require 'active_support/core_ext/hash/slice'
require 'rx/client'

module Rx
  ##
  # Core class responsible for Rx API interface operations on va.gov
  #
  class MedicationsClient < Rx::Client
    include Common::Client::Concerns::MHVSessionBasedClient
    configuration Rx::Configuration
    client_session Rx::ClientSession

    def auth_headers
      Rails.logger.info('Rx request is coming from VA.gov web')
      get_headers(config.base_request_headers.merge('appToken' => config.app_token,
                                                    'mhvCorrelationId' => session.user_id.to_s))
    end

    def get_headers(headers)
      if Settings.mhv.rx.use_new_api.present? && Settings.mhv.rx.use_new_api
        headers.merge('x-api-key' => Settings.mhv.rx.x_api_key)
      else
        headers
      end
    end
  end
end
