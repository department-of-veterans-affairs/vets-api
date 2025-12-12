# frozen_string_literal: true

require 'sidekiq/attr_package'
require 'va_notify/callback_processor'

module VANotify
  class NotificationLookupJob
    include Sidekiq::Job
    include Vets::SharedLogging

    class NotificationNotFound < StandardError; end

    sidekiq_options retry: 5, unique_for: 30.seconds

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      job_class = msg['class']
      error_class = msg['error_class']
      error_message = msg['error_message']
      args = msg['args'] || []

      notification_id = args[0]
      attr_package_params_cache_key = args[1]
      notification_params = Sidekiq::AttrPackage.find(attr_package_params_cache_key) || {}
      notification_type = notification_params['notification_type'] || notification_params[:notification_type]
      status = notification_params['status'] || notification_params[:status]

      context = {
        job_id:,
        job_class:,
        error_class:,
        error_message:,
        notification_id:,
        attr_package_params_cache_key:,
        notification_type:,
        status:
      }.compact

      Rails.logger.error("#{job_class} retries exhausted - notification not found", context)

      tags = [
        "notification_id:#{notification_id}",
        "attr_package_params_cache_key:#{attr_package_params_cache_key}",
        "notification_type:#{notification_type}",
        "status:#{status}"
      ]

      StatsD.increment("sidekiq.jobs.#{job_class.underscore}.retries_exhausted", tags:)
    end

    def perform(notification_id, attr_package_params_cache_key)
      notification_params_hash = Sidekiq::AttrPackage.find(attr_package_params_cache_key)

      unless notification_params_hash
        Rails.logger.error(
          'va_notify notification_lookup_job - Cached params not found for cache key',
          { notification_id:, attr_package_params_cache_key: }
        )
        StatsD.increment('sidekiq.jobs.va_notify_notification_lookup_job.cached_params_not_found')
        return
      end

      notification = VANotify::Notification.find_by(notification_id:)

      if notification
        VANotify::CallbackProcessor.new(notification, notification_params_hash).call

        Sidekiq::AttrPackage.delete(attr_package_params_cache_key)
        StatsD.increment('sidekiq.jobs.va_notify_notification_lookup_job.success')
      else
        raise NotificationNotFound, "Notification #{notification_id} not found"
      end
    end
  end
end
