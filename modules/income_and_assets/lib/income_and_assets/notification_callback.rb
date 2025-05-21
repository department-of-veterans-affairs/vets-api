# frozen_string_literal: true

require 'income_and_assets/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module IncomeAndAssets
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see IncomeAndAssets::Monitor
    def monitor
      @monitor ||= IncomeAndAssets::Monitor.new
    end
  end
end
