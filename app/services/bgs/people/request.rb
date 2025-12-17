# frozen_string_literal: true

module BGS
  # The People module provides Redis-backed caching for BGS (Benefits Gateway Service)
  # person lookups. It wraps remote calls to BGS and caches responses to minimize
  # repeated network requests for the same participant identifiers.
  #
  # This module contains classes that handle both the request logic (via Request)
  # and response handling (via Response) for BGS person data retrieval operations.
  #
  # @example Using the People::Request service
  #   request = BGS::People::Request.new
  #   response = request.find_person_by_participant_id(user: current_user)
  #   if response.ok?
  #     person_data = response.person
  #   end
  module People
    # Request is a Redis-backed wrapper around the BGS People lookup.
    # It provides a cached entrypoint for `find_person_by_participant_id`
    # to avoid repeated remote calls for the same participant id.
    class Request < Common::RedisStore
      include Common::CacheAside

      # Redis key used for caching responses from BGS find_person_by_participant_id
      REDIS_CONFIG_KEY = :bgs_find_person_by_participant_id_response
      redis_config_key REDIS_CONFIG_KEY

      # Public: Retrieve the BGS person response for the given user.
      #
      # user - a User-like object that responds to `participant_id`.
      #
      # Returns a BGS::People::Response instance (may represent :no_id).
      def find_person_by_participant_id(user:)
        find_person_by_participant_id_cached_response(user)
      end

      private

      # Internal: Get the cached response or fetch from BGS if not present.
      #
      # Builds a cache key using the user's participant_id. If no participant_id
      # is available, returns a Response indicating no id was provided.
      #
      # user - a User-like object that responds to `participant_id`.
      #
      # Returns a BGS::People::Response instance.
      def find_person_by_participant_id_cached_response(user)
        user_key = user.participant_id

        # If the user has no participant id, short-circuit with a no_id response.
        return BGS::People::Response.new(nil, status: :no_id) unless user_key

        # do_cached_with will attempt to read from Redis and, on a miss,
        # execute the provided block to fetch fresh data and cache it.
        do_cached_with(key: user_key) do
          # Delegate the actual BGS call to the service layer.
          BGS::People::Service.new(user).find_person_by_participant_id
        end
      end
    end
  end
end
