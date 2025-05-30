# frozen_string_literal: true

module CheckIn
  ##
  # Sidekiq job responsible for sending SMS notifications related to travel claims.
  # This job handles sending text messages to users via VaNotify service,
  # including error handling, retries, and logging.
  #
  # The job tracks SMS API request success/failure. Actual SMS delivery status
  # is tracked via VA Notify callbacks handled by TravelClaimNotificationCallback.
  #
  # @example Enqueue the job with required parameters
  #   CheckIn::TravelClaimNotificationJob.perform_async(
  #     'uuid-123-456',                       # Required - Appointment UUID
  #     '2023-05-15',                         # Required - Appointment date in YYYY-MM-DD format
  #     'template-id-123',                    # Required - VaNotify template ID
  #     '1234'                                # Required - Last four digits of claim number
  #   )
  class TravelClaimNotificationJob < TravelClaimBaseJob
    sidekiq_options retry: 12
    REQUIRED_FIELDS = %i[mobile_phone template_id appointment_date].freeze

    ##
    # Performs the job of sending an SMS notification via VaNotify
    #
    # Validates input parameters, parses the appointment date, and sends the SMS.
    # Returns early if required parameters are missing or date parsing fails.
    # Logs success or failure messages and handles retries via exception re-raising.
    #
    # @param uuid [String] The appointment UUID used to retrieve mobile phone from Redis
    # @param appointment_date [String] The appointment date in YYYY-MM-DD format
    # @param template_id [String] The VaNotify template ID to use for SMS content
    # @param claim_number_last_four [String] The last four digits of claim number for personalization
    # @return [void]
    def perform(uuid, appointment_date, template_id, claim_number_last_four)
      redis_client = TravelClaim::RedisClient.build
      mobile_phone = redis_client.patient_cell_phone(uuid:) || redis_client.mobile_phone(uuid:)
      opts = { mobile_phone:, appointment_date:, template_id:, claim_number_last_four:, uuid: }

      # Early return here because there is no sense in retrying if the required fields are missing
      return unless required_fields_valid?(opts)
      return unless (parsed_date = parse_appointment_date(opts))

      begin
        va_notify_send_sms(opts, parsed_date)
      rescue => e
        message = "Failed to send Travel Claim Notification SMS: #{e.message}"
        self.class.log_sms_attempt(opts, logger, message)

        # Explicit re-raise to trigger the retry mechanism
        raise e
      end

      # Log API request success (not delivery success - that would require VA Notify callbacks)
      message = 'Travel Claim Notification SMS API request succeeded'
      self.class.log_sms_attempt(opts, logger, message)
      StatsD.increment(Constants::STATSD_NOTIFY_SUCCESS)
    end

    ##
    # Callback executed when all retries are exhausted
    #
    # @param job [Hash] The Sidekiq job hash containing job metadata
    # @param ex [Exception] The exception that caused the job to fail
    sidekiq_retries_exhausted do |job, ex|
      CheckIn::TravelClaimNotificationJob.handle_retries_exhausted_failure(job, ex)
    end

    ##
    # Handles errors after all retries have been exhausted
    #
    # Logs the error to Sentry and increments failure metrics based on template type.
    # Job arguments are extracted to retrieve context data from Redis for logging.
    #
    # @param job [Hash] The Sidekiq job hash containing args: [uuid, appointment_date, template_id, claim_number]
    # @param ex [Exception] The exception that caused the job to fail
    # @return [void]
    def self.handle_retries_exhausted_failure(job, ex)
      uuid = job.dig('args', 0)
      template_id = job.dig('args', 2)
      claim_number = job.dig('args', 3)

      redis_client = TravelClaim::RedisClient.build
      phone_number = redis_client.patient_cell_phone(uuid:) || redis_client.mobile_phone(uuid:)
      phone_last_four = TravelClaimNotificationUtilities.phone_last_four(phone_number)

      sentry_context = { template_id:, phone_last_four: }
      sentry_context[:claim_number] = claim_number if claim_number

      SentryLogging.log_exception_to_sentry(
        ex,
        sentry_context,
        { error: :check_in_va_notify_job, team: 'check-in' }
      )

      facility_type = TravelClaimNotificationUtilities.determine_facility_type_from_template(template_id)
      log_failure_no_retry('Retries exhausted', { template_id:, facility_type: })
    end

    ##
    # Logs failure when retries are exhausted or not applicable
    #
    # Increments silent failure metrics and error metrics, then logs the failure message.
    # Used for permanent failures that should not trigger retries.
    #
    # @param message [String] The failure message to log
    # @param opts [Hash, String] Options hash containing template_id/facility_type, or string template_id
    # @param logger_instance [Logger] Logger instance to use (defaults to Rails.logger)
    # @return [Boolean] Always returns false to prevent retries
    def self.log_failure_no_retry(message, opts, logger_instance = Rails.logger)
      template_id = opts&.dig(:template_id) || (opts.is_a?(String) ? opts : nil)
      facility_type = opts&.dig(:facility_type)

      # Use utilities for silent failure metrics
      TravelClaimNotificationUtilities.increment_silent_failure_metrics(template_id, facility_type)

      StatsD.increment(Constants::STATSD_NOTIFY_ERROR)
      failure_message = "Failed to send Travel Claim Notification SMS: #{message}, Won't Retry"
      log_sms_attempt(opts, logger_instance, failure_message)

      # Explicit return here to be sure retry doesn't trigger.
      false
    end

    ##
    # Logs information about SMS sending attempts (success or failure)
    #
    # Extracts phone number last four digits and logs structured data including
    # message, UUID, template ID, and phone last four digits.
    #
    # @param opts [Hash] Options hash containing mobile_phone, template_id, and uuid
    # @param logger_instance [Logger] Logger instance to use (defaults to Rails.logger)
    # @param message [String] The log message (success or failure message)
    # @return [void]
    #
    # @note Does not increment StatsD failure metrics - those are handled after retries are exhausted
    def self.log_sms_attempt(opts, logger_instance = Rails.logger, message)
      phone_number = opts[:mobile_phone]
      phone_last_four = TravelClaimNotificationUtilities.phone_last_four(phone_number)
      template_id = opts[:template_id]
      uuid = opts[:uuid]

      logger_instance.info({ message:, uuid:, template_id:, phone_last_four: })
    end

    private

    ##
    # Validates that all required fields are present
    #
    # @param opts [Hash] Options hash containing mobile_phone, template_id, and appointment_date
    # @return [Boolean] true if all required fields are present, false otherwise
    def required_fields_valid?(opts)
      missing_fields = missing_required_fields(opts)

      return true if missing_fields.empty?

      error_message = "missing #{missing_fields.join(', ')}"
      self.class.log_failure_no_retry(error_message, opts, logger)
      false
    end

    ##
    # Identifies missing required fields from the options hash
    #
    # @param opts [Hash] Options hash containing job parameters
    # @return [Array<String>] List of missing required field names
    def missing_required_fields(opts)
      missing_fields = []
      REQUIRED_FIELDS.each do |field|
        missing_fields << field.to_s if opts&.dig(field).blank?
      end

      missing_fields
    end

    ##
    # Parses the appointment date string into a Date object
    #
    # On parsing failure, logs the error and increments failure metrics.
    #
    # @param opts [Hash] Options hash containing the appointment_date field
    # @return [Date, nil] Parsed date if format is valid, nil if parsing fails
    def parse_appointment_date(opts)
      date_string = opts[:appointment_date]
      DateTime.strptime(date_string.to_s, '%Y-%m-%d').to_date
    rescue
      self.class.log_failure_no_retry('invalid appointment date format', opts, logger)
      nil
    end

    ##
    # Returns a configured instance of the VaNotify client with callback options
    #
    # @param callback_options [Hash] Callback configuration for VA Notify delivery status tracking
    # @return [VaNotify::Service] Configured VaNotify client instance
    def notify_client(callback_options = {})
      VaNotify::Service.new(Settings.vanotify.services.check_in.api_key, callback_options)
    end

    ##
    # Sends the SMS notification using VaNotify service
    #
    # Determines facility type from template ID, selects appropriate SMS sender ID,
    # and configures callback metadata for delivery tracking.
    #
    # @param opts [Hash] Options hash with validated required fields (mobile_phone, template_id, uuid,
    # claim_number_last_four)
    #
    # @param parsed_date [Date] Validated appointment date
    # @return [VaNotify::NotificationResponse] The response from the VaNotify send_sms call
    def va_notify_send_sms(opts, parsed_date)
      template_id = opts[:template_id]
      facility_type = TravelClaimNotificationUtilities.determine_facility_type_from_template(template_id)

      self.class.log_sms_attempt(opts, logger, 'Sending Travel Claim Notification SMS')

      notify_client(build_callback_options(opts)).send_sms(
        phone_number: opts[:mobile_phone],
        template_id:,
        sms_sender_id: determine_sms_sender_id(facility_type),
        personalisation: build_personalisation(opts, parsed_date)
      )
    end

    ##
    # Determines SMS sender ID based on facility type
    #
    # @param facility_type [String] The facility type ('oh' or 'cie')
    # @return [String] The appropriate SMS sender ID constant
    def determine_sms_sender_id(facility_type)
      if facility_type && 'oh'.casecmp?(facility_type)
        Constants::OH_SMS_SENDER_ID
      else
        Constants::CIE_SMS_SENDER_ID
      end
    end

    ##
    # Builds personalisation hash for SMS template
    #
    # @param opts [Hash] Options hash containing claim_number_last_four
    # @param parsed_date [Date] Validated appointment date
    # @return [Hash] Personalisation data for SMS template
    def build_personalisation(opts, parsed_date)
      {
        claim_number: opts[:claim_number_last_four].presence || 'unknown',
        appt_date: parsed_date.strftime('%b %d')
      }
    end

    ##
    # Builds callback options for VA Notify delivery tracking
    #
    # @param opts [Hash] Options hash containing uuid and template_id
    # @return [Hash] Callback configuration for VA Notify
    def build_callback_options(opts)
      {
        callback_klass: 'CheckIn::TravelClaimNotificationCallback',
        callback_metadata: {
          uuid: opts[:uuid],
          template_id: opts[:template_id],
          statsd_tags: {
            'service' => 'check-in',
            'function' => 'travel-claim-notification'
          }
        }
      }
    end
  end
end
