# frozen_string_literal: true

module IvcChampva
  # General purpose callback class used for when we send emails to users.
  # This is used so we can maintain email numbers in DD.
  #
  # Modified from https://github.com/department-of-veterans-affairs/vets-api/tree/master/modules/va_notify#how-teams-can-integrate-with-callbacks
  #

  class EmailNotificationCallback
    def self.call(notification)
      # @param ac [hash] contains properties form_id and form_uuid
      #   (e.g.: {form_id: '10-10d', form_uuid: '12345678-1234-5678-1234-567812345678',
      #   notification_type: 'confirmation'})
      ac = notification.callback_metadata['additional_context'] # TODO: document this type

      # This is the actual contribution we care about:
      monitor.track_email_sent(ac['form_id'], ac['form_uuid'], notification.status, ac['notification_type'])

      case notification.status
      when 'delivered'
        # success
        StatsD.increment('api.vanotify.notifications.delivered')
      when 'permanent-failure'
        # delivery failed
        # possibly log error or increment metric and use the optional metadata - notification.callback_metadata
        StatsD.increment('api.vanotify.notifications.permanent_failure')
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
