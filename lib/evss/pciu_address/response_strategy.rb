# frozen_string_literal: true
require 'common/models/concerns/cache_aside'

module EVSS
  module PCIUAddress
    class ResponseStrategy < Common::RedisStore
      include Common::CacheAside
      redis_config_key :pciu_address_dependencies

      def cache_or_service(key)
        do_cached_with(key: key) { yield }
      end
    end
  end
end
