# frozen_string_literal: true

module VANotify
  class WatchOfficerCallback
    def self.call(notification)
      case notification.status
      when 'delivered'
        StatsD.increment('api.vanotify.notifications.delivered')
      when 'permanent-failure'
        StatsD.increment('api.vanotify.notifications.permanent_failure')
        Rails.logger.error(notification_id: notification.notification_id, source: notification.source_location,
                           status: notification.status, status_reason: notification.status_reason)
      else
        StatsD.increment('api.vanotify.notifications.other')
        Rails.logger.error(notification_id: notification.notification_id, source: notification.source_location,
                           status: notification.status, status_reason: notification.status_reason)
      end
    end
  end
end
