# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'active_support/core_ext/hash/slice'
require 'sm/client_session'
require 'sm/configuration'
require 'sm/client'

module SM
  ##
  # Core class responsible for SM API interface operations on va.gov
  #
  class SMClient < Common::Client::Base
    include Common::Client::Concerns::MHVSessionBasedClient
    configuration SM::Configuration
    client_session SM::ClientSession

    def auth_headers
      Rails.logger.info('SM request is coming from VA.gov web')
      get_headers(config.base_request_headers.merge('appToken' => config.app_token,
                                                    'mhvCorrelationId' => session.user_id.to_s))
    end

    def get_headers(headers)
      if Settings.mhv.sm.use_new_api.present? && Settings.mhv.sm.use_new_api
        headers.merge('x-api-key' => Settings.mhv.sm.x_api_key)
      else
        headers
      end
    end
  end
end
