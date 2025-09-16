# frozen_string_literal: true

require 'dependents_verification/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module DependentsVerification
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see DependentsVerification::Monitor
    def monitor
      @monitor ||= DependentsVerification::Monitor.new
    end
  end
end
