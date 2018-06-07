# frozen_string_literal: true

require 'common/models/concerns/cache_aside'

module EVSS
  module IntentToFile
    class ResponseStrategy < Common::RedisStore
      include Common::CacheAside
      redis_config_key :intent_to_file_response

      def cache_or_service(user_uuid, type)
        conditionally_cache_response(
          key: "#{user_uuid}:#{type}",
          request: -> { yield },
          condition: -> (response) do
            response.ok? && response.intent_to_file.active? && !response.intent_to_file.expires_today?
          end
        )
      end
    end
  end
end
