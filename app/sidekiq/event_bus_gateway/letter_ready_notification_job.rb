# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/attr_package'
require_relative 'constants'
require_relative 'errors'
require_relative 'letter_ready_job_concern'
require_relative 'letter_ready_email_job'
require_relative 'letter_ready_push_job'

module EventBusGateway
  class LetterReadyNotificationJob
    include Sidekiq::Job
    include LetterReadyJobConcern

    STATSD_METRIC_PREFIX = 'event_bus_gateway.letter_ready_notification'

    sidekiq_options retry: Constants::SIDEKIQ_RETRY_COUNT_FIRST_NOTIFICATION

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']
      timestamp = Time.now.utc

      ::Rails.logger.error('LetterReadyNotificationJob retries exhausted',
                           { job_id:, timestamp:, error_class:, error_message: })
      tags = Constants::DD_TAGS + ["function: #{error_message}"]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.exhausted", tags:)
    end

    def perform(participant_id, email_template_id = nil, push_template_id = nil)
      # Fetch participant data upfront
      icn = get_icn(participant_id)

      errors = []
      errors << handle_email_notification(participant_id, email_template_id, icn)
      errors << handle_push_notification(participant_id, push_template_id, icn)
      errors.compact!

      log_completion(email_template_id, push_template_id, errors)
      handle_errors(errors)

      errors
    rescue => e
      # Only catch errors from the initial BGS/MPI lookups
      if e.is_a?(Errors::BgsPersonNotFoundError) ||
         e.is_a?(Errors::MpiProfileNotFoundError) ||
         @bgs_person.nil? || @mpi_profile.nil?
        record_notification_send_failure(e, 'Notification')
      end
      raise
    end

    private

    def should_send_email?(email_template_id, icn)
      email_template_id.present? && icn.present?
    end

    def should_send_push?(push_template_id, icn)
      push_template_id.present? && icn.present?
    end

    def handle_email_notification(participant_id, email_template_id, icn)
      if should_send_email?(email_template_id, icn)
        first_name = get_first_name_from_participant_id(participant_id)

        if first_name.present?
          send_email_async(participant_id, email_template_id, first_name, icn)
        else
          log_notification_skipped('email', 'first_name not present', email_template_id)
          nil
        end
      else
        log_notification_skipped('email', 'ICN or template not available', email_template_id)
        nil
      end
    end

    def handle_push_notification(participant_id, push_template_id, icn)
      unless should_send_push?(push_template_id, icn)
        log_notification_skipped('push', 'ICN or template not available', push_template_id)
        return nil
      end

      unless Flipper.enabled?(:event_bus_gateway_letter_ready_push_notifications, Flipper::Actor.new(icn))
        log_notification_skipped('push', 'Push notifications not enabled for this user', push_template_id)
        return nil
      end

      send_push_async(participant_id, push_template_id, icn)
    end

    def send_email_async(participant_id, email_template_id, first_name, icn)
      # Store PII in Redis and pass only cache key to avoid PII exposure in logs
      cache_key = Sidekiq::AttrPackage.create(first_name:, icn:)
      LetterReadyEmailJob.perform_async(participant_id, email_template_id, cache_key)
      nil
    rescue => e
      log_notification_failure('email', email_template_id, e)
      { type: 'email', error: e.message }
    end

    def send_push_async(participant_id, push_template_id, icn)
      # Store PII in Redis and pass only cache key to avoid PII exposure in logs
      cache_key = Sidekiq::AttrPackage.create(icn:)
      LetterReadyPushJob.perform_async(participant_id, push_template_id, cache_key)
      nil
    rescue => e
      log_notification_failure('push', push_template_id, e)
      { type: 'push', error: e.message }
    end

    def log_notification_failure(notification_type, template_id, error)
      ::Rails.logger.error(
        "LetterReadyNotificationJob #{notification_type} enqueue failed",
        {
          notification_type:,
          template_id:,
          error_class: error.class.name,
          error_message: error.message
        }
      )

      # Track enqueuing failures (different from send failures tracked in child jobs)
      tags = Constants::DD_TAGS + [
        "notification_type:#{notification_type}",
        "error:#{error.class.name}"
      ]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.enqueue_failure", tags:)
    end

    def log_notification_skipped(notification_type, reason, template_id)
      ::Rails.logger.error(
        "LetterReadyNotificationJob #{notification_type} skipped",
        {
          notification_type:,
          reason:,
          template_id:
        }
      )

      tags = Constants::DD_TAGS + [
        "notification_type:#{notification_type}",
        "reason:#{reason.parameterize.underscore}"
      ]
      StatsD.increment("#{STATSD_METRIC_PREFIX}.skipped", tags:)
    end

    def log_completion(email_template_id, push_template_id, errors)
      successful_notifications = []
      successful_notifications << 'email' if email_template_id.present? && errors.none? { |e| e[:type] == 'email' }
      successful_notifications << 'push' if push_template_id.present? && errors.none? { |e| e[:type] == 'push' }

      failed_messages = errors.map { |h| "#{h[:type]}: #{h[:error]}" }.join(', ')

      ::Rails.logger.info(
        'LetterReadyNotificationJob completed',
        {
          notifications_sent: successful_notifications.join(', '),
          notifications_failed: failed_messages,
          email_template_id:,
          push_template_id:
        }
      )
    end

    def handle_errors(errors)
      return if errors.empty?

      if errors.length == 2
        # Both notifications failed to enqueue
        error_details = errors.map { |e| "#{e[:type]}: #{e[:error]}" }.join('; ')
        raise Errors::NotificationEnqueueError, "All notifications failed to enqueue: #{error_details}"
      else
        # Partial failure - determine which notification succeeded
        successful = errors[0][:type] == 'email' ? 'push' : 'email'
        error_messages = errors.map { |h| "#{h[:type]}: #{h[:error]}" }.join(', ')

        ::Rails.logger.warn(
          'LetterReadyNotificationJob partial failure',
          {
            successful:,
            failed: error_messages
          }
        )
      end
    end
  end
end
