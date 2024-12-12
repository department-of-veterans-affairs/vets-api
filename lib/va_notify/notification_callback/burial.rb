# frozen_string_literal: true

require 'burials/monitor'
require 'va_notify/notification_callback/saved_claim'

module Burials
  class NotificationCallback < ::VANotify::NotificationCallback::SavedClaim

    private

    # the monitor to be used
    # @see ZeroSilentFailures::Monitor
    def monitor
      @monitor ||= Burials::Monitor
    end
  end
end
