# frozen_string_literal: true

module Common::Client
  module Monitoring
    extend ActiveSupport::Concern

    def with_monitoring(trace_location = 1)
      caller = caller_locations(trace_location, 1)[0].label
      yield
    rescue => error
      increment_failure(caller, error)
      raise error
    ensure
      increment_total(caller)
    end

    private

    def increment_total(caller)
      increment("#{self.class::STATSD_KEY_PREFIX}.#{caller}.total")
    end

    def increment_failure(caller, error)
      tags = ["error:#{error.class}"]
      tags << "status:#{error.status}" if error.try(:status)

      increment("#{self.class::STATSD_KEY_PREFIX}.#{caller}.fail", tags)
    end
    
    def add_metric_to_stats_roster tag
     Redis.current.sadd("incremented_metrics", tag)
     #set the expire/ttl here?
    end

    def increment(key, tags=nil)
      #Each time we increment a metric, we will add that metric name to our running redis set 
      # TODO this would poll redis for each call of with_monitoring.
      #      we really only need to do this once, if we had a list of all
      add_metric_to_stats_roster(key)
      StatsD.increment(key, 0, tags: tags) unless metric_is_initialized?(key)
      StatsD.increment(key, tags: tags)
    end

    def metric_is_initialized?(key)
      #may not need to do this since redis sets don't store duplicates. 
      Redis.current.sismember("incremented_metrics", key)
    end
  end
end
