# frozen_string_literal: true

module Search
  class Stats
    class << self

      # Triggers the associated StatsD.increment method for the Search buckets that are
      # initialized in the config/initializers/statsd.rb file.
      #
      # @param *args [String] A variable number of string arguments. Each one represents
      #   a bucket in StatsD.  For example passing in ('get_results', 'success') would increment
      #   the 'api.search.get_results.success' bucket
      #
      def increment(*args)
        buckets = args.map(&:downcase).join('.')

        StatsD.increment("Search::STATSD_KEY_PREFIX}.#{buckets}")
      end

      # Increments the associated StatsD bucket with the passed in exception error key.
      #
      # @param key [String] A Search exception key from the locales/exceptions file
      #   For example, 'SEARCH_400'.
      #
       def increment_exception(key)
        StatsD.increment("#{Search::Service::STATSD_KEY_PREFIX}.exceptions", tags: ["exception:#{key.downcase}"])
      end
    end
  end
end