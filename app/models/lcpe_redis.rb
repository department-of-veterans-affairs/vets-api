# frozen_string_literal: true

require 'common/models/concerns/cache_aside'
require 'gi/lcpe/response'

# Facade for GIDS LCPE data
class LCPERedis < Common::RedisStore
  include Common::CacheAside

  redis_config_key :lcpe_response

  attr_reader :lcpe_type

  class ClientCacheStaleError < StandardError; end

  def initialize(*, lcpe_type: nil)
    @lcpe_type = lcpe_type
    super(*)
  end

  def fresh_version_from(gids_response)
    case gids_response.status
    when 304
      cached_response
    else
      # Refresh cache with latest version from GIDS
      invalidate_cache
      do_cached_with(key: lcpe_type) do
        GI::LCPE::Response.from(gids_response)
      end
    end
  end

  def force_client_refresh_and_cache(gids_response)
    v_fresh = gids_response.response_headers['Etag'].match(%r{W/"(\d+)"})[1]
    # no need to cache if vets-api cache already has fresh version
    cache(lcpe_type, GI::LCPE::Response.from(gids_response)) unless v_fresh == cached_version
    raise ClientCacheStaleError
  end

  def cached_response
    self.class.find(lcpe_type)&.response
  end

  def cached_version
    cached_response&.version
  end

  private

  def invalidate_cache
    self.class.delete(lcpe_type)
  end
end
