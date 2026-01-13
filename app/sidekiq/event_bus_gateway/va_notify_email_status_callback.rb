# frozen_string_literal: true

require_relative 'constants'

module EventBusGateway
  class VANotifyEmailStatusCallback
    class EventBusGatewayNotificationNotFoundError < StandardError; end

    class MPIError < StandardError; end

    class MPINameError < StandardError; end

    STATSD_METRIC_PREFIX = 'event_bus_gateway.va_notify_email_status_callback'

    def self.call(notification)
      status = notification.status

      add_metrics(status)
      add_log(notification) if notification.status != 'delivered'
      if notification.status == 'temporary-failure' && Flipper.enabled?(:event_bus_gateway_retry_emails)
        retry_email(notification)
      end
    end

    def self.retry_email(notification)
      ebg_noti = find_notification_by_va_notify_id(notification.notification_id)
      return handle_exhausted_retries(notification, ebg_noti) if ebg_noti.attempts >= Constants::MAX_EMAIL_ATTEMPTS

      schedule_retry_job(ebg_noti)
      StatsD.increment("#{STATSD_METRIC_PREFIX}.queued_retry_success", tags: Constants::DD_TAGS)
    rescue => e
      handle_retry_failure(e)
      raise e
    end

    def self.find_notification_by_va_notify_id(va_notify_id)
      ebg_noti = EventBusGatewayNotification.find_by(va_notify_id:)
      raise EventBusGatewayNotificationNotFoundError if ebg_noti.nil?

      ebg_noti
    end

    def self.handle_exhausted_retries(notification, ebg_noti)
      add_exhausted_retry_log(notification, ebg_noti)
      StatsD.increment("#{STATSD_METRIC_PREFIX}.exhausted_retries", tags: Constants::DD_TAGS)
    end

    def self.schedule_retry_job(ebg_noti)
      icn = ebg_noti.user_account.icn
      if icn.nil?
        Rails.logger.warn('VANotifyEmailStatusCallback ICN is null')
        return false if icn.nil?
      end

      profile = get_profile_by_icn(icn)
      personalisation = {
        host: Constants::HOSTNAME_MAPPING[Settings.hostname] || Settings.hostname,
        first_name: get_first_name(profile)
      }
      EventBusGateway::LetterReadyRetryEmailJob.perform_in(
        1.hour,
        profile.participant_id,
        ebg_noti.template_id,
        personalisation,
        ebg_noti.id
      )
    end

    def self.handle_retry_failure(error)
      Rails.logger.error(name, error.message)
      tags = Constants::DD_TAGS + ["function: #{error.message}"]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.queued_retry_failure", tags:)
    end

    def self.get_first_name(profile)
      first_name = profile.given_names&.first
      raise MPINameError unless first_name

      first_name
    end

    def self.get_profile_by_icn(icn)
      mpi_response = MPI::Service.new.find_profile_by_identifier(identifier: icn, identifier_type: MPI::Constants::ICN)
      raise MPIError unless mpi_response.ok?

      mpi_response.profile
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

    def self.add_exhausted_retry_log(_notification, ebg_notification)
      context = {
        ebg_notification_id: ebg_notification.id,
        max_attempts: Constants::MAX_EMAIL_ATTEMPTS
      }

      Rails.logger.error('EventBusGateway email retries exhausted', context)
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
      StatsD.increment("#{STATSD_METRIC_PREFIX}.va_notify.notifications.#{status}", tags: Constants::DD_TAGS)
    end
  end
end
