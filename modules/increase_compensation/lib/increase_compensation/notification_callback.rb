# frozen_string_literal: true

require 'increase_compensation/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module IncreaseCompensation
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see IncreaseCompensation::Monitor
    def monitor
      @monitor ||= IncreaseCompensation::Monitor.new
    end
  end
end
