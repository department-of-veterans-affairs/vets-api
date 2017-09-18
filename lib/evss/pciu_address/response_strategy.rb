# frozen_string_literal: true
require 'common/models/concerns/cache_aside'
require 'evss/pciu_address/countries_response'
require 'evss/pciu_address/states_response'

module EVSS
  module PCIUAddress
    class ResponseStrategy < Common::RedisStore
      include Common::CacheAside
      redis_config_key :pciu_address_dependencies

      def countries(user)
        do_cached_with(key: :countries) do
          service.get_countries(user)
        end
      end

      def states(user)
        do_cached_with(key: :states) do
          service.get_states(user)
        end
      end

      private

      def service
        @service ||= EVSS::PCIUAddress::Service.new
      end
    end
  end
end
