# frozen_string_literal: true

require 'pensions/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module Pensions
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see Pensions::Monitor
    def monitor
      @monitor ||= Pensions::Monitor.new
    end
  end
end
