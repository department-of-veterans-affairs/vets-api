# frozen_string_literal: true

module SM
  class Client
    module Caching
      private

      # Generic cache wrapper for Secure Messaging collections.
      # Expects the model to implement .get_cached(cache_key) and .set_cached(cache_key, records)
      #
      # @param use_cache [Boolean] whether to attempt to read/write cache
      # @param cache_key [String] key used for the model cache
      # @param model [Class] model class (e.g., Folder, Message, TriageTeam)
      #
      # Yields a block that must return a Vets::Collection
      #
      # @return [Vets::Collection]
      def get_cached_or_fetch_data(use_cache, cache_key, model)
        data = model.get_cached(cache_key) if use_cache
        if data
          Rails.logger.info("secure messaging #{model} cache fetch", cache_key)
          statsd_cache_hit
          Vets::Collection.new(data, model)
        else
          Rails.logger.info("secure messaging #{model} service fetch", cache_key)
          statsd_cache_miss
          yield
        end
      end
    end
  end
end
