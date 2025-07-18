# frozen_string_literal: true

module EventBusGateway
  class VANotifyEmailStatusCallback
    def self.call(notification)
      status = notification.status

      add_metrics(status)
      add_log(notification) if notification.status != 'delivered'
      if notification.status == 'temporary-failure' && Flipper.enabled?(:event_bus_gateway_retry_emails)
        retry_email(notification)
      end
    end

    def self.retry_email(notification)
      ebg_noti = EventBusGatewayNotification.find_by(va_notify_id: notification.id)
      icn = ebg_noti.user_account.icn
      profile = MPI::Service.new.find_profile_by_identifier(
        identifier: icn,
        identifier_type: MPI::Constants::ICN
      ).profile
      EventBusGateway::LetterReadyEmailJob.perform_async(
        profile.participant_id,
        ebg_noti.template_id
      )
    end

    def self.add_log(notification)
      context = {
        notification_id: notification.notification_id,
        source_location: notification.source_location,
        status: notification.status,
        status_reason: notification.status_reason,
        notification_type: notification.notification_type
      }

      Rails.logger.error(name, context)
    end

    def self.add_metrics(status)
      case status
      when 'delivered'
        StatsD.increment('api.vanotify.notifications.delivered')
        StatsD.increment('callbacks.event_bus_gateway.va_notify.notifications.delivered')
      when 'permanent-failure'
        StatsD.increment('api.vanotify.notifications.permanent_failure')
        StatsD.increment('callbacks.event_bus_gateway.va_notify.notifications.permanent_failure')
      when 'temporary-failure'
        StatsD.increment('api.vanotify.notifications.temporary_failure')
        StatsD.increment('callbacks.event_bus_gateway.va_notify.notifications.temporary_failure')
      else
        StatsD.increment('api.vanotify.notifications.other')
        StatsD.increment('callbacks.event_bus_gateway.va_notify.notifications.other')
      end
    end
  end
end
