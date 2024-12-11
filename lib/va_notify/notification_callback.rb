# frozen_string_literal: true

require 'logging/monitor'

module VANotify
  module NotificationCallback
    class Default

      # static call to handle notification callback
      def self.call(notification)
        this = new(notification)

        monitor = Logging::Monitor.new('veteran-facing-forms')
        metric = 'api.vanotify.notifications'
        context = {
          class: this.klass,
          notification_id: notification.notification_id,
          source: notification.source_location,
          status: notification.status,
          status_reason: notification.status_reason
        }

        case notification.status
        when 'delivered'
          # success
          this.on_delivered
          monitor.record(:info, "#{this.klass}: Delivered", "#{metric}.delivered", **context)
        when 'permanent-failure'
          # delivery failed
          # possibly log error or increment metric and use the optional metadata - notification_record.callback_metadata
          this.on_permanent_failure
          monitor.record(:error, "#{this.klass}: Permanent Failure", "#{metric}.permanent_failure", **context)
        when 'temporary-failure'
          # the api will continue attempting to deliver - success is still possible
          this.on_temporary_failure
          monitor.record(:error, "#{this.klass}: Temporary Failure", "#{metric}.temporary_failure", **context)
        else
          this.on_other_status
          monitor.record(:error, "#{this.klass}: Other", "#{metric}.other", **context)
        end
      end

      attr_reader :metadata, :notification

      # instantiate a notification callback
      def initialize(notification)
        @notification = notification
        @metadata = notification.callback_metadata
      end

      # shorthand for _this_ class
      def klass
        self.class.to_s
      end

      # handle the notification callback - inheriting class should override

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
