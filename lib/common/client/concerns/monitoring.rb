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

      increment("#{self.class::STATSD_KEY_PREFIX}.#{caller}.fail", tags: tags)
    end

    def increment(tag)
      # TODO this would poll redis for each call of with_monitoring.
      #      we really only need to do this once, if we had a list of all
      StatsD.increment(tag, 0) unless metric_is_initialized?(tag)
      StatsD.increment(tag)
    end

    def metric_is_initialized?(tag)
      Redis.current.get(tag + ':initialized').present?
    end
  end
end
