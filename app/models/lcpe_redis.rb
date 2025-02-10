# frozen_string_literal: true

require 'common/models/concerns/cache_aside'
require 'gi/lcpe/response'

# Facade for GIDS LCPE data
class LCPERedis < Common::RedisStore
  include Common::CacheAside

  redis_config_key :lcpe_response

  attr_reader :lcpe_type, :v_client, :cached

  class ClientCacheStaleError < StandardError; end

  def initialize(*args, lcpe_type: nil, v_client: nil)
    @lcpe_type = lcpe_type
    @v_client = v_client
    @cached = self.class.find(lcpe_type)
    super(*args)
  end

  def fresh_version_from(response)
    v_fresh = response.response_headers['Etag']

    case response.status
    when 304
      # Forward 304 response from GIDS if client version fresh, otherwise send fresh version from cache
      v_client == v_fresh ? GI::LCPE::Response.from(response) : cached.response
    else
      # Refresh cache with latest version from GIDS
      invalidate_cache
      do_cached_with(key: lcpe_type) do
        GI::LCPE::Response.from(response)
      end
    end
  end

  def force_client_refresh_and_cache(response)
    v_fresh = response.response_headers['Etag']
    # no need to cache if vets-api cache already has fresh version
    cache(lcpe_type, GI::LCPE::Response.from(response)) unless v_fresh == cached_version
    raise ClientCacheStaleError
  end

  def cached_version
    cached&.response&.version
  end

  private

  def invalidate_cache
    self.class.delete(lcpe_type)
  end
end
