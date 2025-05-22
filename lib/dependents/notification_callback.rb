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
      begin
        claim = SavedClaim::DependencyClaim.find(saved_claim_id)
        monitor = claim.monitor
      rescue => e
        monitor = Dependents::Monitor.new(false)
        Rails.logger.warn('Unable to find claim for DependentsNotification', e)
      end
      monitor
    end
  end
end
