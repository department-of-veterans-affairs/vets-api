# frozen_string_literal: true

require 'waterdrop/instrumentation/vendors/datadog/metrics_listener'
require 'datadog/statsd'

module Kafka
  class EnhancedListener < WaterDrop::Instrumentation::Vendors::Datadog::MetricsListener
    BROKER_STATUS_MAPPING = {
      'UP' => Datadog::Statsd::OK,
      'INIT' => Datadog::Statsd::WARNING,
      'CONNECT' => Datadog::Statsd::WARNING,
      'DOWN' => Datadog::Statsd::CRITICAL
    }.freeze

    def broker_service_check(key, *args)
      metric_value, tags = args
      status = BROKER_STATUS_MAPPING.fetch(metric_value, Datadog::Statsd::UNKNOWN)
      client.service_check(
        namespaced_metric(key),
        status,
        tags
      )
    end
  end
end
