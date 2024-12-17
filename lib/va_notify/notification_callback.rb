# frozen_string_literal: true

require 'logging/monitor'

module VANotify
  # notification callbacks
  # - individual teams should inherit VANotify::NotificationCallback::Default
  # - SavedClaim type forms should inherit VANotify::NotificationCallback::SavedClaim
  # - subclasses in lib/va_notify/notification_callback (these are autoloaded via an initializer)
  #
  # @see config/initializers/va_notify_callbacks.rb
  module NotificationCallback
    # custom error to catch a notification being submitted to an incorrect handler
    class CallbackClassMismatch < StandardError
      def initialize(requested, called)
        super("notification requested #{requested}, but called #{called}")
      end
    end

    # generic parent class for a notification callback
    class Default

      STATSD = 'api.vanotify.notification.callback'

      # static call to handle notification callback
      # creates an instance of _this_ class and will call the status function
      #
      # @param notification [VANotify::Notification] ActiveRecord of notification.
      def self.call(notification)
        callback = new(notification)

        monitor = Logging::Monitor.new('vanotify-notification-callback')
        context = callback.context

        case notification.status
        when 'delivered'
          # success
          callback.on_delivered
          monitor.track(:info, "#{callback.klass}: Delivered", "#{STATSD}.delivered", **context)

        when 'permanent-failure'
          # delivery failed - log error
          callback.on_permanent_failure
          monitor.track(:error, "#{callback.klass}: Permanent Failure", "#{STATSD}.permanent_failure", **context)

        when 'temporary-failure'
          # the api will continue attempting to deliver - success is still possible
          callback.on_temporary_failure
          monitor.track(:warn, "#{callback.klass}: Temporary Failure", "#{STATSD}.temporary_failure", **context)

        else
          callback.on_other_status
          monitor.track(:warn, "#{callback.klass}: Other", "#{STATSD}.other", **context)
        end
      end

      attr_reader :metadata, :notification

      # instantiate a notification callback
      #
      # @param notification [VANotify::Notification] model object from vanotify
      def initialize(notification)
        raise VANotify::NotificationCallback::CallbackClassMismatch.new(notification.callback_klass, klass) unless klass == notification.callback_klass

        @notification = notification
        @metadata = notification.callback_metadata || {}

        # inheriting class can add an attr_reader for the expected metadata keys
        metadata.each do |key, value|
          instance_variable_set("@#{key}", value)
        end
      end

      # shorthand for _this_ class
      def klass
        self.class.to_s
      end

      # default monitor tracking context
      def context
        {
          notification_id: notification.notification_id,
          notification_type: notification.notification_type,
          source: notification.source_location,
          status: notification.status,
          status_reason: notification.status_reason,
          callback_klass: klass,
          callback_metadata: metadata
        }
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

      private

      # is the notification an email
      # - currently the notification_type is 'email' or nil
      #
      # @return boolean
      def email?
        notification.notification_type == 'email'
      end

      # custom call location to be sent with monitoring
      def call_location
        nil
      end
    end
  end
end
