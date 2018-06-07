# frozen_string_literal: true

require 'common/models/concerns/cache_aside'

module EVSS
  module IntentToFile
    class ResponseStrategy < Common::RedisStore
      include Common::CacheAside
      redis_config_key :intent_to_file_response

      def cache_or_service(user_uuid, type)
        do_cached_with(key: "#{user_uuid}:#{type}") { yield }
      end
    end
  end
end
