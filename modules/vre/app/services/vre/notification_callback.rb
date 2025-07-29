# frozen_string_literal: true

module VRE
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # @see Logging::Monitor
    def monitor
      @monitor ||= VRE::VREMonitor.new
    end
  end
end
