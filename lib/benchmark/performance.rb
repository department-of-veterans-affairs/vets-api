# frozen_string_literal: true

module Benchmark
  class Performance
    FE = 'frontend'
    PAGE_PERFORMANCE = 'page_performance'

    # Calls StatsD.measure with the passed benchmarking data. StatsD.measure lets
    # you benchmark how long the execution of a specific task/method takes.
    #
    # The StatsD gem will raise ArgumentErrors if the correct params are not supplied.
    #
    # Snake_cases the passed key for the call to StatsD.
    #
    # @param key [String] A StatsD key. See https://github.com/Shopify/statsd-instrument#statsd-keys
    # @param duration [Float] Duration of benchmark measurement in milliseconds
    # @param tags [Array<String>] An array of string tag names. Tags must be in the key:value
    #   format in the string.  For example:
    #   ['page_id:initial_pageload', 'page_id:dom_loaded']
    # @return [StatsD::Instrument::Metric] The metric that was sent to StatsD
    # @see https://github.com/Shopify/statsd-instrument#statsdmeasure
    #
    def self.track(key, duration, tags:)
      Whitelist.new(tags).authorize!
      StatsD.measure(key&.underscore, duration, tags: tags)
    rescue ArgumentError => e
      raise Common::Exceptions::ParameterMissing.new('Missing parameter', detail: e&.message)
    end

    # Calls StatsD.measure with benchmark data for the passed page and metric.
    #
    # Checks for presence of 'metric'. Delegates check for duration to StatsD.
    #
    # @param metric [String] Creates a namespace/bucket for what is being
    #   measured.  For example, 'initial_pageload', 'dom_loaded', etc.
    # @param duration [Float] Duration of benchmark measurement in milliseconds
    # @param page_id [String] A unique identifier for the FE page being benchmarked
    # @return [StatsD::Instrument::Metric] The metric that was sent to StatsD
    #
    def self.by_page_and_metric(metric, duration, page_id)
      check_for_metric! metric

      stats_d_key = "#{FE}.#{PAGE_PERFORMANCE}.#{metric}"
      track(stats_d_key, duration, tags: ["page_id:#{page_id}"])
    end

    # Calls StatsD.measure for a given page, for a given set of metrics and durations.
    #
    # @param page_id [String] A unique identifier for the FE page being benchmarked
    # @param metrics_data [Array<Hash>] An array of hash metric data.  Hash must
    #   have two keys: 'metric' and 'duration'. For example:
    #   [
    #     { "metric": "initial_page_load", "duration": 1234.56 }
    #     { "metric": "time_to_paint", "duration": 123.45 }
    #   ]
    # @return [Array<StatsD::Instrument::Metric>] An array of metrics that were sent to StatsD
    #
    def self.metrics_for_page(page_id, metrics_data)
      metrics_data.map do |metrics|
        by_page_and_metric(metrics['metric'], metrics['duration'], page_id)
      end
    end

    class << self
      private

      def check_for_metric!(metric)
        if metric.blank?
          raise Common::Exceptions::ParameterMissing.new(
            'Missing parameter',
            detail: 'A value for metric is required.'
          )
        end
      end
    end
  end
end
