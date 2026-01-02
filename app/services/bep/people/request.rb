# frozen_string_literal: true

module BEP
  # The People module provides Redis-backed caching for BEP (Benefits Enterprise Platform)
  # person lookups. It wraps remote calls to BEP and caches responses to minimize
  # repeated network requests for the same participant identifiers.
  #
  # This module contains classes that handle both the request logic (via Request)
  # and response handling (via Response) for BEP person data retrieval operations.
  #
  # @example Using the People::Request service
  #   request = BEP::People::Request.new
  #   response = request.find_person_by_participant_id(user: current_user)
  #   if response.ok?
  #     person_data = response.person
  #   end
  module People
    # Request is a Redis-backed wrapper around the BEP People lookup.
    # It provides a cached entrypoint for `find_person_by_participant_id`
    # to avoid repeated remote calls for the same participant id.
    class Request < Common::RedisStore
      include Common::CacheAside

      # Redis key used for caching responses from BEP find_person_by_participant_id
      REDIS_CONFIG_KEY = :bep_find_person_by_participant_id_response
      redis_config_key REDIS_CONFIG_KEY

      # Public: Retrieve the BEP person response for the given user.
      #
      # user - a User-like object that responds to `participant_id`.
      #
      # Returns a BEP::People::Response instance (may represent :no_id).
      def find_person_by_participant_id(user:)
        find_person_by_participant_id_cached_response(user)
      end

      private

      # Internal: Get the cached response or fetch from BEP if not present.
      #
      # Builds a cache key using the user's participant_id. If no participant_id
      # is available, returns a Response indicating no id was provided.
      #
      # user - a User-like object that responds to `participant_id`.
      #
      # Returns a BEP::People::Response instance.
      def find_person_by_participant_id_cached_response(user)
        user_key = user.participant_id

        # If the user has no participant id, short-circuit with a no_id response.
        return BEP::People::Response.new(nil, status: :no_id) unless user_key

        # do_cached_with will attempt to read from Redis and, on a miss,
        # execute the provided block to fetch fresh data and cache it.
        do_cached_with(key: user_key) do
          # Delegate the actual BEP call to the service layer.
          BEP::People::Service.new(user).find_person_by_participant_id
        end
      end
    end
  end
end
