# frozen_string_literal: true

module Benchmark
  class Performance
    FE = 'frontend'
    PAGE_PERFORMANCE = 'page_performance'

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
    rescue ArgumentError => error
      raise Common::Exceptions::ParameterMissing.new('Missing parameter', detail: error&.message)
    end

    # Calls StatsD.measure with benchmark data for the passed page and metric.
    #
    # @param metric [String] Creates a namespace/bucket for what is being
    #   measured.  For example, 'initial_pageload', 'dom_loaded', etc.
    # @param duration [Float] Duration of benchmark measurement in milliseconds
    # @param page_id [String] A unique identifier for the FE page being benchmarked
    # @return [StatsD::Instrument::Metric] The metric that was sent to StatsD
    #
    def self.by_page_and_metric(metric, duration, page_id)
      stats_d_key = "#{FE}.#{PAGE_PERFORMANCE}.#{metric}"

      track(stats_d_key, duration, tags: [page_id])
    end
  end
end
