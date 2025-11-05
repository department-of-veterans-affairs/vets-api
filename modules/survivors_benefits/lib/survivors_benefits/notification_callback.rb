# frozen_string_literal: true

require 'survivors_benefits/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module SurvivorsBenefits
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see SurvivorsBenefits::Monitor
    def monitor
      @monitor ||= SurvivorsBenefits::Monitor.new
    end
  end
end
