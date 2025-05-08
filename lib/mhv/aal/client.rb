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

    ##
    # Create an AAL (account activity log) entry in MHV.
    #
    # @param [Hash] attributes - The AAL attributes to send
    # @param [Boolean] once_per_session - Whether this log should be limited to once per session
    # @param [Common::UTCTime] session_id - Unique identifier for the user's VA.gov session, e.g. last_signed_in
    #
    def create_aal(attributes, once_per_session, session_id)
      if once_per_session
        # 1) Build a hash of everything except completion_time
        redis_key = aal_redis_key(attributes, session_id)

        # 2) If we already logged it this session, do not re-log
        return if redis.exists?(redis_key)

        # 3) Otherwise mark it sent for the duration of the session
        redis.set(redis_key, true, nx: false, ex: REDIS_CONFIG[:mhv_aal_log_store][:each_ttl])
      end

      attributes[:user_profile_id] = session.user_id.to_s
      form = AAL::CreateAALForm.new(attributes)

      perform(:post, 'usermgmt/activity', form.params, token_headers) if Flipper.enabled?(:mhv_enable_aal_integration)
    end

    private

    ##
    # Build a unique key for this AAL, based on the user, unique VA.gov session ID, and AAL
    # attributes. Only some attributes apply towards the unique fingerprint. For example,
    # completion_time is not included.
    #
    def aal_redis_key(attributes, session_id)
      track_h = attributes
                .except(:completion_time)
                .merge(session_id:)

      fingerprint = Digest::MD5.hexdigest(
        track_h.sort.to_h.to_json
      )

      "aal:#{session.user_id}:#{fingerprint}"
    end

    def redis
      Redis::Namespace.new(REDIS_CONFIG[:mhv_aal_log_store][:namespace], redis: $redis)
    end

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
