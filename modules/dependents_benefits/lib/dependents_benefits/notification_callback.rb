# frozen_string_literal: true

require 'dependents_benefits/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module DependentsBenefits
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see DependentsBenefits::Monitor
    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end
  end
end
