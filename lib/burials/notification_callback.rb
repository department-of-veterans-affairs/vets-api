# frozen_string_literal: true

require 'burials/monitor'
require 'va_notify/notification_callback/saved_claim'

module Burials
  # @see ::VANotify::NotificationCallback::SavedClaim
  class NotificationCallback < ::VANotify::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see Burials::Monitor
    def monitor
      @monitor ||= Burials::Monitor.new
    end
  end
end
