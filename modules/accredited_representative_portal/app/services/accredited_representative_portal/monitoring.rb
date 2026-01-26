# frozen_string_literal: true

module AccreditedRepresentativePortal
  class Monitoring
    NAME = 'accredited-representative-portal'

    def initialize(service = NAME, default_tags: [])
      @service = service
      @default_tags = default_tags
    end

    def track_count(metric, tags: [])
      StatsD.increment(metric, tags: merge_tags(tags))
    end

    def track_duration(metric, from: Time.current, to: Time.current, tags: [])
      duration_time_ms = ((to - from) * 1000).to_i
      StatsD.distribution(metric, duration_time_ms, tags: merge_tags(tags))
    end

    def trace(span_name, tags: {}, root_tags: {})
      span_tags  = compact_tags(tags)
      trace_tags = compact_tags(root_tags)

      Datadog::Tracing.trace(span_name, service: @service) do |span|
        # span-level tags
        span_tags.each { |k, v| span.set_tag(k, v) }

        # optional root/trace-level tags (use sparingly)
        if (trace = Datadog::Tracing.active_trace)
          trace_tags.each { |k, v| trace.set_tag(k, v) }
        end

        begin
          yield(span)
        rescue => e
          span.set_error(e)
          raise
        end
      end
    end

    private

    def merge_tags(tags)
      (tags + default_service_tags).uniq
    end

    def default_service_tags
      [@default_tags, "service:#{@service}"].flatten.compact
    end

    def compact_tags(h)
      (h || {}).each_with_object({}) do |(k, v), acc|
        next if v.nil? || (v.respond_to?(:empty?) && v.empty?)

        acc[k] = v
      end
    end
  end
end
