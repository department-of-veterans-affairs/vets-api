# frozen_string_literal: true

module AccreditedRepresentativePortal
  class MonitoringService
    SERVICE_NAME = 'accredited-representative-portal'
    METRIC_BASE = 'api.arp'

    def initialize(service = SERVICE_NAME)
      @service = service
      @monitor = ::Logging::Monitor.new(service)
    end

    def track_event(level, message, metric, tags = [])
      with_tracing(metric) do |span|
        span.set_tag('event.message', message)
        span.set_tag('event.level', level)
        span.set_tag('event.tags', tags.join(', '))

        @monitor.track(level, message, format_metric(metric), tags: tags)
      end
    end

    def track_error(message, metric, error_class = nil, tags = [])
      with_tracing(metric) do |span|
        span.set_error(StandardError.new(message))
        span.set_tag('error.class', error_class) if error_class

        all_tags = tags.dup
        all_tags << "error:#{error_class}" if error_class
        span.set_tag('error.tags', all_tags.join(', '))

        @monitor.track(:error, message, format_metric(metric), tags: all_tags)
      end
    end

    def with_tracing(metric)
      Datadog::Tracing.trace(format_metric(metric)) do |span|
        span.service = @service
        span.resource = metric

        # Ensure proper parent-child linking
        parent_span = Datadog::Tracing.active_span
        span.set_tag('parent.trace_id', parent_span.trace_id) if parent_span.respond_to?(:trace_id)
        span.set_tag('parent.span_id', parent_span.span_id) if parent_span.respond_to?(:span_id)

        # Measure execution time
        start_time = Time.zone.now
        result = yield(span) if block_given?
        duration = Time.zone.now - start_time

        span.set_tag('execution_time', duration)

        result
      end
    end

    private

    def format_metric(metric)
      metric.start_with?(METRIC_BASE) ? metric : "#{METRIC_BASE}.#{metric}"
    end
  end
end
