# frozen_string_literal: true

module Benchmark
  class Performance
    FE = 'frontend'
    PAGE_LOAD = 'page_load'

    # Calls StatsD.measure with the passed benchmarking data.
    #
    # @param key [String] A StatsD key. See https://github.com/Shopify/statsd-instrument#statsd-keys
    # @param duration [Float] Duration of benchmark measurement in milliseconds
    # @param tags [Array<String>] An array of string tag names
    # @return [StatsD::Instrument::Metric] The metric that was sent to StatsD
    # @see https://github.com/Shopify/statsd-instrument#statsdmeasure
    #
    def self.track(key, duration, tags:)
      StatsD.measure(key, duration, tags: tags)
    end

    # Calls StatsD.measure with frontend page load data.
    #
    # @param duration [Float] Duration of benchmark measurement in milliseconds
    # @param page_id [String] A unique identifier for the FE page being benchmarked
    # @return [StatsD::Instrument::Metric] The metric that was sent to StatsD
    #
    def self.page_load(duration, page_id)
      stats_d_key = "#{FE}.#{PAGE_LOAD}"

      track(stats_d_key, duration, tags: [page_id])
    end
  end
end
