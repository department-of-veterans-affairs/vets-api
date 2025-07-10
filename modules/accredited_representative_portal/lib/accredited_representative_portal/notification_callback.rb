# frozen_string_literal: true

require 'accredited_representative_portal/monitor'
require 'veteran_facing_services/notification_callback/saved_claim'

module AccreditedRepresentativePortal
  # @see ::VeteranFacingServices::NotificationCallback::SavedClaim
  class NotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see AccreditedRepresentativePortal::Monitor
    def monitor
      @monitor ||= AccreditedRepresentativePortal::Monitor.new
    end
  end
end
