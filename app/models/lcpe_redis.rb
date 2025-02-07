# frozen_string_literal: true

require 'common/models/concerns/cache_aside'
require 'gi/lcpe/response'

# Facade for GIDS LCPE data
class LCPERedis < Common::RedisStore
  include Common::CacheAside

  redis_config_key :lcpe_response

  def response_from(key:, v_client:, response:)
    v_gids = response.response_headers['Etag']

    case response.status
    when 304
      cached_response = self.class.find(key) unless v_client == v_gids
      GI::LCPE::Response.from(cached_response || response)
    else
      do_cached_with(key:) do
        GI::LCPE::Response.from(response:, latest_version: v_gids)
      end
    end
  end
end
