# frozen_string_literal: true

require 'pensions/monitor'
require 'va_notify/notification_callback/saved_claim'

module Pensions
  class NotificationCallback < ::VANotify::NotificationCallback::SavedClaim
    private

    # the monitor to be used
    # @see Pensions::Monitor
    def monitor
      @monitor ||= Pensions::Monitor
    end
  end
end
