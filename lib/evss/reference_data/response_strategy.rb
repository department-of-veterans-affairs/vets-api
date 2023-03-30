# frozen_string_literal: true

module EVSS
  module ReferenceData
    class ResponseStrategy < Common::RedisStore
      include Common::CacheAside
      redis_config_key :reference_data_response

      def cache_by_user_and_type(user_uuid, type, &)
        do_cached_with(key: "#{user_uuid}:#{type}", &)
      end
    end
  end
end
