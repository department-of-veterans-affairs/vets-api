# frozen_string_literal: true

require 'dependents/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module Dependents
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see Dependents::Monitor
    def monitor
      @monitor ||= Dependents::Monitor.new
    end
  end
end
