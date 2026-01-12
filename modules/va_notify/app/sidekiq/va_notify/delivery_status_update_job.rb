# frozen_string_literal: true

require 'sidekiq/attr_package'

module VANotify
  class DeliveryStatusUpdateJob
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
      Sidekiq::AttrPackage.delete(attr_package_params_cache_key) if attr_package_params_cache_key
    end

    def perform(notification_id, attr_package_params_cache_key) # rubocop:disable Metrics/MethodLength
      notification_params_hash = Sidekiq::AttrPackage.find(attr_package_params_cache_key)

      unless notification_params_hash
        Rails.logger.error(
          'va_notify delivery_status_update_job - Cached params not found for cache key',
          { notification_id:, attr_package_params_cache_key: }
        )
        StatsD.increment('sidekiq.jobs.va_notify_delivery_status_update_job.cached_params_not_found')
        return
      end

      notification = VANotify::Notification.find_by(notification_id:)
      if notification
        notification.update(notification_params_hash)
        log_successful_update(notification)

        VANotify::DefaultCallback.new(notification).call
        VANotify::CustomCallback.new(notification_params_hash.merge(id: notification_id)).call
        Sidekiq::AttrPackage.delete(attr_package_params_cache_key)
        StatsD.increment('sidekiq.jobs.va_notify_delivery_status_update_job.success')
      else
        raise NotificationNotFound, "Notification #{notification_id} not found; retrying until exhaustion"
      end
    rescue Sidekiq::AttrPackageError => e
      # Log AttrPackage errors as application logic errors (no retries)
      Rails.logger.error('VANotifyEmailJob AttrPackage error', { error: e.message })
      raise ArgumentError, e.message
    end

    def log_successful_update(notification)
      Rails.logger.info("va_notify callbacks - Updating notification: #{notification.id}",
                        {
                          notification_id: notification.id,
                          source_location: notification.source_location,
                          template_id: notification.template_id,
                          callback_metadata: notification.callback_metadata,
                          status: notification.status,
                          status_reason: notification.status_reason
                        })
    end
  end
end
