# frozen_string_literal: true

module IvcChampva
  # Callback class used for when we notify a user that their
  # form has been missing a Pega status for > `failure_email_threshold_days`.
  #
  # Modified from https://github.com/department-of-veterans-affairs/vets-api/tree/master/modules/va_notify#how-teams-can-integrate-with-callbacks
  #

  class ZsfEmailNotificationCallback
    def self.call(notification)
      # @param ac [hash] contains properties form_id and form_uuid
      #   (e.g.: {form_id: '10-10d', form_uuid: '12345678-1234-5678-1234-567812345678'})
      ac = notification.callback_metadata['additional_context'] # TODO: document this type
      case notification.status
      when 'delivered'
        # success
        StatsD.increment('api.vanotify.notifications.delivered')
        monitor.log_silent_failure_avoided(ac) # Log with email_confirmed
        monitor.track_missing_status_email_sent(ac['form_id']) # e.g., '10-10d'
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
