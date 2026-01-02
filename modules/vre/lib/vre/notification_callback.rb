# frozen_string_literal: true

module VRE
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    def monitor
      @monitor ||= VRE::VREMonitor.new
    end
  end
end
