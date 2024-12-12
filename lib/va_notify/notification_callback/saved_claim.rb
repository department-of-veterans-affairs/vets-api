# frozen_string_literal: true

require 'va_notify/notification_callback'

module VANotify
  module NotificationCallback
    class SavedClaim < ::VANotify::NotificationCallback::Default

      # notification was delivered
      def on_delivered
        nil
      end

      # notification has permanently failed
      def on_permanent_failure
        nil
      end

      # notification has temporarily failed
      def on_temporary_failure
        nil
      end

      # notification has an unknown status
      def on_other_status
        nil
      end

    end
  end
end
