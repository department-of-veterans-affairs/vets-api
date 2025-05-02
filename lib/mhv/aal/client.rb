# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
require 'mhv/aal/client_session'
require 'mhv/aal/configuration'
require 'mhv/aal/create_aal_form'

module AAL
  ##
  # Core class responsible for MHV Account Activity Log API interface operations
  #
  class Client < Common::Client::Base
    include Common::Client::Concerns::MHVSessionBasedClient

    def create_aal(attributes)
      attributes[:user_profile_id] = session.user_id.to_s
      form = AAL::CreateAALForm.new(attributes)

      perform(:post, 'usermgmt/activity', form.params, token_headers) if Flipper.enabled?(:mhv_enable_aal_integration)
    end

    private

    ##
    # Overriding MHVSessionBasedClient's method to add x-api-key
    #
    def token_headers
      super.merge('x-api-key' => config.x_api_key)
    end

    ##
    # Overriding MHVSessionBasedClient's method to add x-api-key
    #
    def auth_headers
      super.merge('x-api-key' => config.x_api_key)
    end

    ##
    # Overriding MHVSessionBasedClient's method, because we need more control over the path.
    #
    def get_session_tagged
      perform(:get, 'usermgmt/auth/session', nil, auth_headers)
    end
  end

  class MRClient < Client
    include Common::Client::Concerns::MHVSessionBasedClient

    configuration AAL::MRConfiguration
    client_session AAL::MRClientSession

    def session_config_key
      :mhv_aal_mr_session_lock
    end
  end

  class RXClient < Client
    include Common::Client::Concerns::MHVSessionBasedClient

    configuration AAL::RXConfiguration
    client_session AAL::RXClientSession

    def session_config_key
      :mhv_aal_rx_session_lock
    end
  end

  class SMClient < Client
    include Common::Client::Concerns::MHVSessionBasedClient

    configuration AAL::SMConfiguration
    client_session AAL::SMClientSession

    def session_config_key
      :mhv_aal_sm_session_lock
    end
  end
end
