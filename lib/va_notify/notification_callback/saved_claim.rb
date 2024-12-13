# frozen_string_literal: true

require 'va_notify/notification_callback'
require 'zero_silent_failures/monitor'

module VANotify
  module NotificationCallback
    class SavedClaim < ::VANotify::NotificationCallback::Default

      # instantiate a notification callback
      def initialize(notification)
        super(notification)
      end

      # notification was delivered
      def on_delivered
        update_database if email?

        if email? && email_type == 'error'
          monitor.log_silent_failure_avoided(zsf_additional_context, email_confirmed: true, call_location:)
        end
      end

      # notification has permanently failed
      def on_permanent_failure
        update_database if email?

        if email? && email_type == 'error'
          monitor.log_silent_failure(zsf_additional_context, call_location:)
        end
      end

      # notification has temporarily failed
      def on_temporary_failure
        update_database if email?
      end

      # notification has an unknown status
      def on_other_status
        update_database if email?
      end

      private

      # expected metadata values
      attr_reader :form_id, :saved_claim_id, :email_template_id, :email_type, :service_name

      def claim_va_notification
        @cvn ||= ClaimVANotification.find_by(form_type: form_id, saved_claim_id:, email_template_id:)
      end

      def update_database
        return unless claim_va_notification
        claim_va_notification.update(**notification_context)
      end

      # the monitor to be used
      # @see ZeroSilentFailures::Monitor
      def monitor
        @monitor ||= ZeroSilentFailures::Monitor.new(service_name)
      end

      def notification_context
        {
          notification_id: notification.id,
          notification_uuid: notification.notification_id,
          notification_type: notification.notification_type,
          notification_status: notification.status
        }
      end

      def zsf_additional_context
        {
          callback_class: notification.callback_klass,
          **metadata,
          **notification_context
        }
      end

      def call_location
        nil
      end
    end
  end
end
