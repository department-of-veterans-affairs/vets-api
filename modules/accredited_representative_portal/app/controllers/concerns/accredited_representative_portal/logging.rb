# frozen_string_literal: true

module AccreditedRepresentativePortal
  module Logging
    extend ActiveSupport::Concern

    private

    def monitor
      @monitor ||= MonitoringService.new(self.class::SERVICE_NAME)
    end

    def log_info(message, metric, tags = [])
      monitor.track_event(:info, message, metric, tags)
    end

    def log_warn(message, metric, tags = [])
      monitor.track_event(:warn, message, metric, tags)
    end

    def log_error(message, metric, error_class = nil, tags = [])
      monitor.track_error(message, metric, error_class, tags)
    end

    def user_tags(extra_tags = [])
      ["user:#{@current_user&.uuid || 'unknown'}"] + extra_tags
    end
  end
end
