# frozen_string_literal: true

module AccreditedRepresentativePortal
  module ControllerTracking
    extend ActiveSupport::Concern

    private

    def monitor
      @monitor ||= Monitoring::Service.new(
        Monitoring::Service::NAME,
        user_context: current_user
      )
    end

    def track_request(message = nil, tags: [])
      monitor.track_request(
        message: message,
        metric: Monitoring::Metric::POA,
        tags: standard_tags + tags
      )
    end

    def track_error(message:, error: StandardError, tags: [])
      monitor.track_error(
        message: message,
        metric: Monitoring::Metric::POA,
        error: error,
        tags: standard_tags + tags
      )
    end

    def standard_tags
      [
        Monitoring::Tag::Operation::ACTION.call(controller_name, action_name),
        Monitoring::Tag::Source::API,
        "service:#{Monitoring::Service::NAME}"
      ].compact
    end
  end
end
