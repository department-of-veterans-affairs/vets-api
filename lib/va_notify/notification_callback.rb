# frozen_string_literal: true

require 'logging/monitor'

module VANotify
  module NotificationCallback
    class Default

      def self.call(notification)
        this = new(notification)
        this.call

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
          monitor.monitor(:info, "#{this.klass}: Delivered", "#{metric}.delivered", **context)
        when 'permanent-failure'
          # delivery failed
          # possibly log error or increment metric and use the optional metadata - notification_record.callback_metadata
          monitor.monitor(:error, "#{this.klass}: Permanent Failure", "#{metric}.permanent_failure", **context)
        when 'temporary-failure'
          # the api will continue attempting to deliver - success is still possible
          monitor.monitor(:error, "#{this.klass}: Temporary Failure", "#{metric}.temporary_failure", **context)
        else
          monitor.monitor(:error, "#{this.klass}: Other", "#{metric}.other", **context)
        end
      end

      def initialize(notification)
        @notification = notification
        @metadata = notification.callback_metadata
      end

      def call
        # inheriting class should override
        nil
      end

      def klass
        self.class.to_s
      end

      private

      attr_reader :metadata, :notification

    end
  end
end
