# frozen_string_literal: true

require 'common/models/concerns/cache_aside'

class CacheHandler < Common::RedisStore
  include Common::CacheAside

  redis_config_key :ask_va_response

  def cache_data(key, &)
    do_cached_with(key:, &)
  end
end
