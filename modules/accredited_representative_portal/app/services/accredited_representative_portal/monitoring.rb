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

    private

    def merge_tags(tags)
      (tags + default_service_tags).uniq
    end

    def default_service_tags
      [@default_tags, "service:#{@service}"].flatten.compact
    end
  end
end
