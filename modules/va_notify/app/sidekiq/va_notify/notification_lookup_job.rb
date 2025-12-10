# frozen_string_literal: true

require 'va_notify/default_callback'
require 'va_notify/custom_callback'

module VANotify
  class NotificationLookupJob
    include Sidekiq::Job
    include Vets::SharedLogging

    sidekiq_options retry: 5, unique_for: 30.seconds

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg["jid"]
      job_class = msg["class"]
      error_class = msg["error_class"]
      error_message = msg["error_message"]
      args = msg["args"] || []

      notification_id = args[0]
      notification_params = args[1] || {}
      notification_type = notification_params["notification_type"]
      status = notification_params["status"]

      context = {
        job_id:,
        job_class:,
        error_class:,
        error_message:,
        notification_id:,
        notification_type:,
        status:
      }.compact

      Rails.logger.error("#{job_class} retries exhausted - notification not found", context)

      tags = [
        "notification_id:#{notification_id}",
        "notification_type:#{notification_type}",
        "status:#{status}"
      ]

      StatsD.increment("sidekiq.jobs.#{job_class.underscore}.retries_exhausted", tags:)
    end

    def perform(notification_id, notification_params_hash)
      notification = VANotify::Notification.find_by(notification_id:)

      if notification
        notification.update(notification_params_hash)

        Rails.logger.info("va_notify notification_lookup_job - Found and updated notification: #{notification.id}", {
          notification_id: notification.id,
          source_location: notification.source_location,
          template_id: notification.template_id,
          callback_metadata: notification.callback_metadata,
          status: notification.status,
          status_reason: notification.status_reason
        })

        VANotify::DefaultCallback.new(notification).call
        VANotify::CustomCallback.new(notification_params_hash.merge(id: notification_id)).call

        StatsD.increment("sidekiq.jobs.va_notify_notification_lookup_job.success")
      else
        Rails.logger.warn("va_notify notification_lookup_job - Notification still not found: #{notification_id}")
        StatsD.increment("sidekiq.jobs.va_notify_notification_lookup_job.not_found")
      end
    end
  end
end
