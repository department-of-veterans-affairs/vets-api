# frozen_string_literal: true

module AccreditedRepresentativePortal
  class MonitoringService
    def initialize(service_name)
      @monitor = ::Logging::Monitor.new(service_name)
    end

    def track_event(level, message, metric, tags = [])
      @monitor.track(level, message, metric, tags: tags)
    end

    def track_error(message, metric, error_class = nil, tags = [])
      tags << "error:#{error_class}" if error_class
      track_event(:error, message, metric, tags)
    end
  end
end
