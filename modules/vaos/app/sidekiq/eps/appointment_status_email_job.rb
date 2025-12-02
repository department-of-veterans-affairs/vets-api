# frozen_string_literal: true

module Eps
  ##
  # Sidekiq job responsible for sending appointment status notification emails
  # when appointment processing encounters errors.
  #
  # This job fetches appointment data from Redis and sends failure notification
  # emails to users via VA Notify service. It includes retry logic and
  # comprehensive error handling for different types of failures.
  #
  # @example Enqueue the job
  #   Eps::AppointmentStatusEmailJob.perform_async(user_uuid, appointment_id_last4, error_message)
  #
  class AppointmentStatusEmailJob
    include Sidekiq::Job
    include VAOS::CommunityCareConstants

    # 14 retries to span approximately 25 hours, this is to allow for unexpected outage of the
    # external messaging service. If the service is down for more than 25 hours, the job will
    # be sent to the dead queue where it can be manually retried once it is confirmed the service
    # is back up.
    sidekiq_options retry: 14
    STATSD_KEY = "#{STATSD_PREFIX}.appointment_status_email_job".freeze
    STATSD_NOTIFY_SILENT_FAILURE = 'silent_failure'
    STATSD_CC_SILENT_FAILURE_TAGS = [
      COMMUNITY_CARE_SERVICE_TAG,
      'function:appointment_status_email_job'
    ].freeze

    ##
    # Main job execution method that processes appointment status email notifications.
    #
    # Fetches appointment data from Redis and sends a notification email to the user
    # about appointment processing failures. Includes comprehensive error handling
    # with appropriate retry logic based on error types.
    #
    # @param user_uuid [String] The UUID of the user associated with the appointment
    # @param appointment_id_last4 [String] The last 4 digits of the appointment ID
    # @param error [String, nil] Optional error message to include in the notification
    # @return [void]
    #
    def perform(user_uuid, appointment_id_last4, error = nil)
      email = fetch_email(user_uuid, appointment_id_last4)
      return unless email

      send_notification_email(email:, user_uuid:, appointment_id_last4:, error:)
    rescue => e
      handle_exception(error: e, user_uuid:, appointment_id_last4:)
    end

    ##
    # Sidekiq callback executed when all retry attempts have been exhausted.
    #
    # Logs the final failure with detailed error information and marks it as permanent
    # to prevent further retry attempts.
    #
    sidekiq_retries_exhausted do |msg, ex|
      error_class = msg['error_class']
      error_message = msg['error_message']
      user_uuid = msg['args'][0]
      appointment_id_last4 = msg['args'][1]

      message = "#{self.class} retries exhausted: " \
                "#{error_class} - #{error_message}"
      log_failure(error: ex, message:, user_uuid:, appointment_id_last4:, permanent: true)
    end

    ##
    # Logs job failures with appropriate error tracking and metrics.
    #
    # Handles both temporary failures (which allow retries) and permanent failures
    # (which stop retry attempts). Logs to Rails logger, and StatsD for
    # comprehensive error tracking.
    #
    # @param error [Exception] The exception that caused the failure
    # @param message [String] Human-readable error message for logging
    # @param user_uuid [String] The UUID of the user associated with the failure
    # @param appointment_id_last4 [String] The last 4 digits of the appointment ID
    # @param permanent [Boolean] Whether this is a permanent failure (default: false)
    # @return [void]
    # @raise [Exception] Re-raises the original error if not permanent
    #
    def self.log_failure(error:, message:, user_uuid:, appointment_id_last4:, permanent: false)
      error_data = {
        error_class: error.class.name,
        error_message: error.message,
        user_uuid:,
        appointment_id_last4:
      }

      Rails.logger.error("#{CC_APPOINTMENTS}: #{message}", error_data)

      if permanent
        StatsD.increment("#{STATSD_KEY}.failure", tags: [COMMUNITY_CARE_SERVICE_TAG])
        StatsD.increment(STATSD_NOTIFY_SILENT_FAILURE, tags: STATSD_CC_SILENT_FAILURE_TAGS)
      else
        raise error
      end
    end

    private

    ##
    # Sends appointment failure notification email to the user via VA Notify service.
    #
    # Uses the VA Notify service to send a templated email notification about
    # appointment processing failures to the user's registered email address.
    # Includes callback configuration for delivery status tracking.
    #
    # @param email [String] The email address to send the notification to
    # @param user_uuid [String] The UUID of the user associated with the appointment
    # @param appointment_id_last4 [String] The last 4 digits of the appointment ID
    # @param error [String, nil] Error message to include in the email template
    # @return [void]
    #
    def send_notification_email(email:, user_uuid:, appointment_id_last4:, error:)
      notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key,
                                            email_callback_options(user_uuid, appointment_id_last4))

      notify_client.send_email(
        email_address: email,
        template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
        personalisation: { 'error' => error }
      )
    end

    ##
    # Fetches the email address from Redis using the provided user UUID and appointment ID.
    #
    # Retrieves cached appointment information from Redis and extracts the email address.
    # Validates that both the appointment data and email are present. Handles missing
    # data scenarios by logging permanent failures.
    #
    # @param user_uuid [String] The UUID of the user associated with the appointment
    # @param appointment_id_last4 [String] The last 4 digits of the appointment ID
    # @return [String, nil] Email address if successful, nil if data is missing or invalid
    #
    def fetch_email(user_uuid, appointment_id_last4)
      redis_client = Eps::RedisClient.new
      appointment_data = redis_client.fetch_appointment_data(uuid: user_uuid, appointment_id: appointment_id_last4)

      raise ArgumentError, 'missing appointment data' if appointment_data.nil?

      email = appointment_data[:email]
      raise ArgumentError, 'missing email' if email.blank?

      email
    rescue ArgumentError => e
      message = "#{self.class} #{e.message}: " \
                "User UUID: #{user_uuid} - Appointment ID: #{appointment_id_last4}"
      self.class.log_failure(error: e, message:, user_uuid:, appointment_id_last4:, permanent: true)
      nil
    end

    ##
    # Handles different types of exceptions with appropriate retry logic.
    #
    # Categorizes exceptions based on HTTP status codes and error types to determine
    # whether the job should be retried or marked as permanently failed:
    # - 4xx errors: Permanent failures (client errors, won't retry)
    # - 5xx errors: Temporary failures (server errors, will retry)
    # - Other errors: Permanent failures (unexpected errors)
    #
    # @param error [Exception] The exception to handle
    # @param user_uuid [String] The UUID of the user associated with the error
    # @param appointment_id_last4 [String] The last 4 digits of the appointment ID
    # @return [void]
    #
    def handle_exception(error:, user_uuid:, appointment_id_last4:)
      if error.respond_to?(:status_code) && error.status_code >= 400 && error.status_code < 500
        message = "#{self.class} upstream error - will not retry: " \
                  "#{error.status_code} - #{error.message}"
        self.class.log_failure(error:, message:, user_uuid:, appointment_id_last4:, permanent: true)
      elsif error.respond_to?(:status_code)
        message = "#{self.class} upstream error - will retry: " \
                  "#{error.status_code} - #{error.message}"
        self.class.log_failure(error:, message:, user_uuid:, appointment_id_last4:, permanent: false)
      else
        message = "#{self.class} unexpected error: " \
                  "#{error.class.name} - #{error.message}"
        self.class.log_failure(error:, message:, user_uuid:, appointment_id_last4:, permanent: true)
      end
    end

    def email_callback_options(user_uuid, appointment_id_last4)
      return unless Flipper.enabled?(:vaos_appointment_notification_callback)

      {
        callback_klass: 'Eps::AppointmentStatusNotificationCallback',
        callback_metadata: {
          user_uuid:,
          appointment_id_last4:,
          statsd_tags: {
            service: 'community_care_appointments',
            function: 'appointment_submission_failure_notification'
          }
        }
      }
    end
  end
end
