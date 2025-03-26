# frozen_string_literal: true

require 'veteran_facing_services/notification_callback'
require_relative 'notification_monitor'

module DecisionReviews
  class EvidenceNotificationCallback < ::VeteranFacingServices::NotificationCallback::Default
    def update_database
      DecisionReviewNotificationAuditLog.create!(
        notification_id: notification.notification_id,
        reference: notification.reference,
        status: notification.status,
        payload: notification.to_json
      )
    end

    # notification was delivered
    def on_delivered
      update_database

      if email? && email_type.to_s == 'error'
        monitor.log_silent_failure_avoided(context, email_confirmed: true, call_location:)
      end
    end

    # notification has permanently failed
    def on_permanent_failure
      update_database

      monitor.log_silent_failure(context, call_location:) if email? && email_type.to_s == 'error'
    end

    # notification has temporarily failed
    def on_temporary_failure
      update_database
    end

    # notification has an unknown status
    def on_other_status
      update_database
    end

    private

    attr_reader :email_template_id, :email_type, :service_name

    def monitor
      DecisionReviews::NotificationMonitor.new(service_name)
    end
  end
end
