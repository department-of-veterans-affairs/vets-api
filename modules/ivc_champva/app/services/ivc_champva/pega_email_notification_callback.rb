# frozen_string_literal: true

module IvcChampva
  # Callback class used for when we notify Pega about a form missing a Pega status
  #
  # Modified from https://github.com/department-of-veterans-affairs/vets-api/tree/master/modules/va_notify#how-teams-can-integrate-with-callbacks
  #

  class PegaEmailNotificationCallback
    def self.call(notification)
      # @param ac [hash] contains properties form_id, form_uuid, and notification_type
      # as defined under callback_metadata.additional_context when the email was sent
      #   (e.g.: {form_id: '10-10d', form_uuid: '12345678-1234-5678-1234-567812345678',
      #   notification_type: 'pega_alert'})
      ac = notification.callback_metadata['additional_context']
      case notification.status
      when 'delivered'
        # success
        StatsD.increment('api.vanotify.notifications.delivered')
        monitor.track_pega_alert_email_sent(ac['form_id']) # e.g., '10-10d'
      when 'permanent-failure'
        # delivery failed
        StatsD.increment('api.vanotify.notifications.permanent_failure')
        monitor.track_pega_alert_email_failed(ac['form_id'], notification.status, notification.status_reason)
        Rails.logger.error(notification_id: notification.notification_id, source: notification.source_location,
                           status: notification.status, status_reason: notification.status_reason)
      when 'temporary-failure'
        # the api will continue attempting to deliver - success is still possible
        StatsD.increment('api.vanotify.notifications.temporary_failure')
        Rails.logger.error(notification_id: notification.notification_id, source: notification.source_location,
                           status: notification.status, status_reason: notification.status_reason)
      else
        StatsD.increment('api.vanotify.notifications.other')
        Rails.logger.error(notification_id: notification.notification_id, source: notification.source_location,
                           status: notification.status, status_reason: notification.status_reason)
      end
    end

    ##
    # retreive a monitor for tracking
    #
    # @return [IvcChampva::Monitor]
    #
    def self.monitor
      IvcChampva::Monitor.new
    end
  end
end
