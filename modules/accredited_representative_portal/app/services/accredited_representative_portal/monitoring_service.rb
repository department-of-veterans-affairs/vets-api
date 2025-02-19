# frozen_string_literal: true

module AccreditedRepresentativePortal
  class MonitoringService
    SERVICE_NAME = 'accredited-representative-portal'

    def initialize(service = SERVICE_NAME)
      @service = service
      @monitor = ::Logging::Monitor.new(service)
    end

    def track_event(level, message, metric, tags = [])
      with_tracing(metric) do |span|
        span.set_tag('event.message', message)
        span.set_tag('event.level', level)
        span.set_tag('event.tags', tags.join(', '))

        @monitor.track(level, message, metric, tags: tags)
      end
    end

    def track_error(message, metric, error_class = nil, tags = [])
      with_tracing(metric) do |span|
        span.set_error(StandardError.new(message))
        span.set_tag('error.class', error_class) if error_class

        all_tags = tags.dup
        all_tags << "error:#{error_class}" if error_class
        span.set_tag('error.tags', all_tags.join(', '))

        @monitor.track(:error, message, metric, tags: all_tags)
      end
    end

    def with_tracing(metric)
      Datadog::Tracing.trace(metric) do |span|
        span.service = @service
        span.resource = metric

        yield(span) if block_given?
      end
    end
  end
end
