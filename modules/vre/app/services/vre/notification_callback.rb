# frozen_string_literal: true

module VRE
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    def self.handle_failure(**args)
      new.handle_failure(**args)
    end

    def handle_failure(**args)
      monitor.track_submission_exhaustion(args[:message])
      monitor.log_silent_failure(
        { message: args[:message] },
        nil,
        call_location: caller_locations.first
      )
    end

    def handle_success(**args)
      monitor.track_submission_exhaustion(args[:message])
      monitor.log_silent_failure_avoided(
        { message: args[:message] },
        nil,
        call_location: caller_locations.first
      )
    end

    private

    def monitor
      @monitor ||= VRE::VREMonitor.new
    end
  end
end
