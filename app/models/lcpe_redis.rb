# frozen_string_literal: true

require 'common/models/concerns/cache_aside'
require 'gi/lcpe/response'

# Facade for GIDS LCPE data
class LCPERedis < Common::RedisStore
  include Common::CacheAside

  redis_config_key :lcpe_response

  class ClientCacheStaleError < StandardError; end

  def response_from(key:, v_client:, response:)
    v_latest = response.response_headers['Etag']

    case response.status
    when 304
      cached = self.class.find(key) unless v_client == v_latest
      # Return cached response if client version stale, otherwise forward 304
      cached&.response && GI::LCPE::Response.from(response:, v_latest:)
    else
      do_cached_with(key:) do
        GI::LCPE::Response.from(response:, v_latest:)
      end
    end
  end

  def force_client_refresh_and_cache(key:, response:)
    v_latest = response.response_headers['Etag']
    # no need to cache if redis has latest version
    unless self.class.cached_version(key) == v_latest
      cache(key, GI::LCPE::Response.from(response:, v_latest:))
    end
    raise ClientCacheStaleError
  end

  def self.cached_version(key)
    find(key)&.response&.version
  end
end
