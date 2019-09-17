# frozen_string_literal: true

module Common::Client
  module Monitoring
    extend ActiveSupport::Concern

    def with_monitoring(trace_location = 1)
      caller = caller_locations(trace_location, 1)[0].label
      yield
    rescue => e
      increment_failure(caller, e)
      raise e
    ensure
      increment_total(caller)
    end

    def increment_total(caller)
      StatsD.increment("#{self.class::STATSD_KEY_PREFIX}.#{caller}.total")
    end

    def increment_failure(caller, error)
      tags = ["error:#{error.class}"]
      tags << "status:#{error.status}" if error.try(:status)
      StatsD.increment("#{self.class::STATSD_KEY_PREFIX}.#{caller}.fail", tags: tags)
    end
  end
end
