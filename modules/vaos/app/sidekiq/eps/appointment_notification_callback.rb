# frozen_string_literal: true

module Eps
  class AppointmentNotificationCallback
    STATSD_KEY = 'api.vaos.appointment_status_notification'

    def self.call(notification)
      metadata = notification.callback_metadata || {}

      base_data = {
        notification_id: notification.notification_id,
        user_uuid: metadata['user_uuid'] || 'missing',
        appointment_id_last4: metadata['appointment_id_last4'] || 'missing'
      }

      handle_notification_status(notification, base_data)
    end

    def self.handle_notification_status(notification, base_data)
      tags = build_statsd_tags(base_data)

      if notification.status == 'delivered'
        StatsD.increment("#{STATSD_KEY}.success", tags:)
        Rails.logger.info('Appointment status notification delivered', base_data)
      else
        StatsD.increment("#{STATSD_KEY}.failure", tags:)
        failure_data = base_data.merge(
          status: notification.status,
          status_reason: notification.status_reason
        )
        Rails.logger.error('Appointment status notification failed', failure_data)
      end
    end

    def self.build_statsd_tags(base_data)
      [
        "user_uuid:#{base_data[:user_uuid] || 'missing'}",
        "appointment_id_last4:#{base_data[:appointment_id_last4] || 'missing'}"
      ].compact
    end
  end
end
