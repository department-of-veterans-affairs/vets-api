# frozen_string_literal: true

require 'common/models/concerns/cache_aside'
require 'evss/pciu_address/countries_response'
require 'evss/pciu_address/states_response'

module EVSS
  module PCIUAddress
    class ResponseStrategy < Common::RedisStore
      include Common::CacheAside
      redis_config_key :pciu_address_dependencies

      def cache_or_service(key, &block)
        do_cached_with(key: key, &block)
      end
    end
  end
end
