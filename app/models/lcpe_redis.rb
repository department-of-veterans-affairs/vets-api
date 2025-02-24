# frozen_string_literal: true

require 'common/models/concerns/cache_aside'
require 'gi/lcpe/response'

# Facade for GIDS LCPE data
class LCPERedis < Common::RedisStore
  include Common::CacheAside

  redis_config_key :lcpe_response

  attr_reader :lcpe_type

  class ClientCacheStaleError < StandardError; end

  # default nil for lcpe_type because Common::RedisStore.find raises ArgumentError otherwise
  def initialize(*, lcpe_type: nil)
    @lcpe_type = lcpe_type
    super(*)
  end

  def fresh_version_from(raw_response)
    case raw_response.status
    when 304
      cached_response
    else
      # Refresh cache with latest version from GIDS
      clear_cache if raw_response.success?
      do_cached_with(key: lcpe_type) do
        GI::LCPE::Response.from(raw_response)
      end
    end
  end

  def force_client_refresh_and_cache(raw_response)
    v_fresh = raw_response.response_headers['Etag']
    # no need to cache if vets-api cache already has fresh version
    cache(lcpe_type, GI::LCPE::Response.from(raw_response)) unless v_fresh == cached_version
    raise ClientCacheStaleError
  end

  def cached_response
    @cached_response ||= self.class.find(lcpe_type)&.response
  end

  def cached_version
    cached_response&.version
  end

  private

  def clear_cache
    self.class.delete(lcpe_type)
  end
end
