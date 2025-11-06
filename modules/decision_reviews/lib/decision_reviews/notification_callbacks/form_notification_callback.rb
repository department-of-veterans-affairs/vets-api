# frozen_string_literal: true

require 'veteran_facing_services/notification_callback/saved_claim'
require_relative 'notification_monitor'

module DecisionReviews
  class FormNotificationCallback < ::VeteranFacingServices::NotificationCallback::SavedClaim
    attr_reader :reference

    def update_database
      DecisionReviewNotificationAuditLog.create!(
        notification_id: notification.notification_id,
        reference:,
        status: notification.status,
        payload: notification.to_json
      )
    end

    private

    def monitor
      DecisionReviews::NotificationMonitor.new(service_name)
    end
  end
end
