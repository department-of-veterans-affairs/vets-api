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
      # Fetch BGS and MPI data once upfront
      bgs_person = get_bgs_person(participant_id)
      mpi_profile = get_mpi_profile(participant_id)

      notifications_sent = []
      errors = []

      # Send email notification if template provided
      if email_template_id.present? && bgs_person&.dig(:first_nm).present? && mpi_profile&.icn.present?
        begin
          LetterReadyEmailJob.perform_async(participant_id, email_template_id, bgs_person.dig(:first_nm), mpi_profile.icn)
          notifications_sent << 'email'
        rescue => e
          errors << { type: 'email', error: e.message }
          ::Rails.logger.error('LetterReadyNotificationJob email failed', {
                                 participant_id:,
                                 email_template_id:,
                                 error: e.message
                               })
        end
      end

      # Send push notification if template provided and ICN available
      if push_template_id.present? && mpi_profile&.icn.present?
        begin
          LetterReadyPushJob.perform_async(participant_id, push_template_id, mpi_profile.icn)
          notifications_sent << 'push'
        rescue => e
          errors << { type: 'push', error: e.message }
          ::Rails.logger.error('LetterReadyNotificationJob push failed', {
                                 participant_id:,
                                 push_template_id:,
                                 error: e.message
                               })
        end
      end

      # Log completion status
      ::Rails.logger.info('LetterReadyNotificationJob completed', {
                            participant_id:,
                            notifications_sent: notifications_sent.join(', '),
                            notifications_failed: errors.map { |h| "#{h[:type]}: #{h[:error]}" }.join(', '),
                            email_template_id:,
                            push_template_id:
                          })

      # Re-raise if ALL notifications failed, otherwise consider it a partial success
      if errors.any? && notifications_sent.empty?
        raise
      elsif errors.any?
        # Log warning for partial failures but don't raise (some notifications succeeded)
        error_messages = errors.map { |h| "#{h[:type]}: #{h[:error]}" }.join(', ')
        ::Rails.logger.warn('LetterReadyNotificationJob partial failure', {
                              participant_id:,
                              successful: notifications_sent.join(', '),
                              failed: error_messages
                            })
      end
      errors
    rescue => e
      # Only catch errors from the initial BGS/MPI lookups, others are caught in individual rescues above
      record_notification_send_failure(e, 'Notification') if bgs_person.nil? || mpi_profile.nil?
      raise
    end
  end
end
