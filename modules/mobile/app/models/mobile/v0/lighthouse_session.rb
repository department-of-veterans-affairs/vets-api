# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    # Stores the session attributes returned from the Lighthouse token endpoint.
    # Mixes in the RedisCaching concern so the token can be cached for the length
    # (in seconds) of the expires_in attribute
    #
    class LighthouseSession < Common::Resource
      CACHE_VERSION = 1

      include Mobile::V0::Concerns::RedisCaching

      redis_config REDIS_CONFIG[:mobile_app_lighthouse_session_store], CACHE_VERSION

      attribute :access_token, Types::Strict::String
      attribute :expires_in, Types::Coercible::Integer
    end
  end
end
