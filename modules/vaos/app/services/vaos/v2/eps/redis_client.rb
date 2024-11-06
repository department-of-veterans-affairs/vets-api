# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

module VAOS
  module V2
    module Eps
      class RedisClient < Common::RedisStore
        include Common::CacheAside

        redis_config_key :eps_appointment_access_token

        def store(access_token)
          cache('jwt-bearer', access_token)
        end
      end
    end
  end
end
