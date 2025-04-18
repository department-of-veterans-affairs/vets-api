# frozen_string_literal: true

require 'income_and_assets/submissions/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module IncomeAndAssets
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see IncomeAndAssets::Submissions::Monitor
    def monitor
      @monitor ||= IncomeAndAssets::Submissions::Monitor.new
    end
  end
end
