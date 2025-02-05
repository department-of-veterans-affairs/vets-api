# frozen_string_literal: true

require 'common/models/concerns/cache_aside'
require 'gi/lcpe/response'

# Facade for GIDS LCPE data
class LCPERedis < Common::RedisStore
  include Common::CacheAside

  redis_config_key :lcpe_response

  def response_from_redis_or_service(key:, response:)
    # self.class.delete(key) if response.response_headers['invalidate-redis-cache']
    self.class.delete(key) if true

    do_cached_with(key:) do
      GI::LCPE::Response.from(response)
    end
  end
end
