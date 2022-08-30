# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

module BGS
  module People
    class Request < Common::RedisStore
      include Common::CacheAside

      REDIS_CONFIG_KEY = :bgs_find_person_by_participant_id_response
      redis_config_key REDIS_CONFIG_KEY

      def find_person_by_participant_id(user:)
        find_person_by_participant_id_cached_response(user)
      end

      private

      def find_person_by_participant_id_cached_response(user)
        user_key = user.participant_id

        return BGS::People::Response.new(nil, status: :no_id) unless user_key

        do_cached_with(key: user_key) do
          BGS::People::Service.new(user).find_person_by_participant_id
        end
      end
    end
  end
end
