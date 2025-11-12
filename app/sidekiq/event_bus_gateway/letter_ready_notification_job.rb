# frozen_string_literal: true

require 'sidekiq'
require_relative 'constants'
require_relative 'letter_ready_job_concern'
require_relative 'letter_ready_email_job'
require_relative 'letter_ready_push_job'

module EventBusGateway
  class LetterReadyNotificationJob
    include Sidekiq::Job
    include LetterReadyJobConcern

    STATSD_METRIC_PREFIX = 'event_bus_gateway.letter_ready_notification'

    sidekiq_options Constants::SIDEKIQ_RETRY_OPTIONS

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
      get_mpi_profile(participant_id)
      icn = get_icn(participant_id)

      errors = []

      # Send email notification if template provided and ICN available
      if email_template_id.present? && icn.present?
        first_name = get_first_name_from_participant_id(participant_id)

        errors << send_email_async(participant_id, email_template_id, first_name, icn) if first_name.present?
      end

      # Send push notification if template provided and ICN available
      errors << send_push_async(participant_id, push_template_id, icn) if should_send_push?(push_template_id, icn)

      errors.compact!

      log_completion(participant_id, email_template_id, push_template_id, errors)
      handle_errors(errors)

      errors
    rescue => e
      # Only catch errors from the initial BGS/MPI lookups
      record_notification_send_failure(e, 'Notification') if @bgs_person.nil? || @mpi_profile.nil?
      raise
    end

    private

    def should_send_push?(push_template_id, icn)
      push_template_id.present? && icn.present?
    end

    def send_email_async(participant_id, email_template_id, first_name, icn)
      LetterReadyEmailJob.perform_async(participant_id, email_template_id, first_name, icn)
      nil
    rescue => e
      log_notification_failure('email', participant_id, email_template_id, e)
      { type: 'email', error: e.message }
    end

    def send_push_async(participant_id, push_template_id, icn)
      LetterReadyPushJob.perform_async(participant_id, push_template_id, icn)
      nil
    rescue => e
      log_notification_failure('push', participant_id, push_template_id, e)
      { type: 'push', error: e.message }
    end

    def log_notification_failure(notification_type, participant_id, template_id, error)
      ::Rails.logger.error(
        "LetterReadyNotificationJob #{notification_type} failed",
        {
          participant_id:,
          template_id:,
          error: error.message
        }
      )
    end

    def log_completion(participant_id, email_template_id, push_template_id, errors)
      successful_notifications = []
      successful_notifications << 'email' if email_template_id.present? && errors.none? { |e| e[:type] == 'email' }
      successful_notifications << 'push' if push_template_id.present? && errors.none? { |e| e[:type] == 'push' }

      failed_messages = errors.map { |h| "#{h[:type]}: #{h[:error]}" }.join(', ')

      ::Rails.logger.info(
        'LetterReadyNotificationJob completed',
        {
          participant_id:,
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
        # Both notifications failed
        raise StandardError, "All notifications failed: #{errors.map { |e| e[:error] }.join('; ')}"
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
