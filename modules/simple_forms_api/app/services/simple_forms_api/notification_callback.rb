# frozen_string_literal: true

require 'logging/call_location'
require 'va_notify/notification_callback/saved_claim'
require 'zero_silent_failures/monitor'

module SimpleFormsApi
  # @see ::VANotify::NotificationCallback::SavedClaim
  class NotificationCallback < ::VANotify::NotificationCallback::SavedClaim
    # instantiate a notification callback
    # @see VANotify::NotificationCallback::Default#new
    def initialize(notification)
      super(notification)

      @service = statsd_tags['service']
      @function = statsd_tags['function']
    end

    # notification was delivered
    def on_delivered
      if email? && notification_type.to_s == 'error'
        monitor.log_silent_failure_avoided(context, email_confirmed: true, call_location:)
      end
    end

    # notification has permanently failed
    def on_permanent_failure
      monitor.log_silent_failure(context, call_location:) if email? && notification_type.to_s == 'error'
    end

    # notification has temporarily failed
    def on_temporary_failure
      nil
    end

    # notification has an unknown status
    def on_other_status
      nil
    end

    private

    attr_reader :notification_type, :statsd_tags, :service, :function

    # the monitor to be used
    # @see ZeroSilentFailures::Monitor
    def monitor
      @monitor ||= ZeroSilentFailures::Monitor.new(service)
    end

    # custom call location to be sent with monitoring
    def call_location
      Logging::CallLocation.customize(caller_locations.first, function:)
    end
  end
end
