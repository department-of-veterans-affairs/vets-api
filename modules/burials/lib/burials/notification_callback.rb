# frozen_string_literal: true

require 'burials/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module Burials
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see Burials::Monitor
    def monitor
      @monitor ||= Burials::Monitor.new
    end
  end
end
