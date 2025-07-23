# frozen_string_literal: true

require 'waterdrop/instrumentation/vendors/datadog/metrics_listener'
require 'datadog/statsd'

module Kafka
  class EnhancedListener < WaterDrop::Instrumentation::Vendors::Datadog::MetricsListener
    def service_check(key, *args)
      metric_value, tags = args
      status = case metric_value
               when 'UP'
                 Datadog::Statsd::OK
               when 'INIT', 'TRY_CONNECT'
                 Datadog::Statsd::WARNING
               when 'DOWN'
                 Datadog::Statsd::CRITICAL
               else
                 Datadog::Statsd::UNKNOWN
               end
      client.service_check(
        namespaced_metric(key),
        status,
        tags
      )
    end
  end
end
