# frozen_string_literal: true

module Dependents
  class DependentsEmailNotificationCallback
    def self.call(notification)
      # @param ac [hash] contains properties form_id and form_uuid
      ac = notification.callback_metadata['additional_context'] # TODO: document this type
      case notification.status
      when 'delivered'
        # success
        StatsD.increment('api.vanotify.notifications.delivered')
        monitor.log_silent_failure_avoided(ac, email_confirmed: true) # Log with email_confirmed
        monitor.track_missing_status_email_sent(ac['form_id']) # e.g., '686C-674'
      when 'permanent-failure'
        # delivery failed
        # possibly log error or increment metric and use the optional metadata - notification.callback_metadata
        StatsD.increment('api.vanotify.notifications.permanent_failure')
        Rails.logger.error(notification_id: notification.notification_id, source: notification.source_location,
                           status: notification.status, status_reason: notification.status_reason)
        # Log our silent failure since the email never reached the user
        monitor.log_silent_failure(ac)
      when 'temporary-failure'
        # the api will continue attempting to deliver - success is still possible
        StatsD.increment('api.vanotify.notifications.permanent_failure')
        Rails.logger.error(notification_id: notification.notification_id, source: notification.source_location,
                           status: notification.status, status_reason: notification.status_reason)
      else
        StatsD.increment('api.vanotify.notifications.other')
        Rails.logger.error(notification_id: notification.notification_id, source: notification.source_location,
                           status: notification.status, status_reason: notification.status_reason)
      end
    end

    def self.monitor
      Dependents::Monitor.new
    end
  end
end
