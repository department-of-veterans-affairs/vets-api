# frozen_string_literal: true

module CheckIn
  # Sidekiq job responsible for sending SMS notifications related to travel claims.
  # This job handles sending text messages to users via VaNotify service,
  # including error handling, retries, and logging.
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

    # Performs the job of sending an SMS notification via VaNotify
    #
    # Validates input parameters, logs the attempt, and handles success/failure
    # metrics. Returns early if required parameters like mobile_phone are missing.
    # The claim number is directly passed to the job.
    #
    # @param uuid [String] The appointment UUID used to retrieve data from Redis
    # @param appointment_date [String] The appointment date in YYYY-MM-DD format
    # @param template_id [String] The VaNotify template ID to use
    # @param claim_number_last_four [String] The last four digits of claim number
    # @return [void]
    def perform(uuid, appointment_date, template_id, claim_number_last_four)
      redis_client = TravelClaim::RedisClient.build

      opts = {
        mobile_phone: redis_client.patient_cell_phone(uuid:) || redis_client.mobile_phone(uuid:),
        appointment_date:,
        template_id:,
        facility_type: redis_client.facility_type(uuid:),
        claim_number_last_four:,
        uuid:
      }

      # Early return here because there is no sense in retrying if the required fields are missing
      return false unless required_fields_valid?(opts)

      parsed_date = parse_appointment_date(opts)
      return false if parsed_date.nil?

      begin
        log_sending_travel_claim_notification(opts)
        va_notify_send_sms(opts, parsed_date)
        log_success(opts)
      rescue => e
        self.class.log_send_sms_failure(e.message, opts, logger)

        # Explicit re-raise to trigger the retry mechanism
        raise e
      end
    end

    # Callback executed when all retries are exhausted
    # @param job [Hash] The Sidekiq job hash containing job metadata
    # @param ex [Exception] The exception that caused the job to fail
    sidekiq_retries_exhausted do |job, ex|
      CheckIn::TravelClaimNotificationJob.handle_retries_exhausted_failure(job, ex)
    end

    # Handles errors after all retries have been exhausted
    # Logs the error to Sentry and updates metrics based on the template type and facility.
    # The UUID and template ID are extracted from job arguments, and additional data like
    # phone number and claim number are retrieved from Redis.
    #
    # @param job [Hash] The Sidekiq job hash containing job metadata
    # @param ex [Exception] The exception that caused the job to fail
    # @return [void]
    def self.handle_retries_exhausted_failure(job, ex)
      uuid = job.dig('args', 0)
      template_id = job.dig('args', 2)
      claim_number = job.dig('args', 3)

      redis_client = TravelClaim::RedisClient.build
      phone_number = redis_client.patient_cell_phone(uuid:) || redis_client.mobile_phone(uuid:)
      phone_last_four = phone_number ? phone_number.delete('^0-9').last(4) : 'unknown'

      sentry_context = { template_id:, phone_last_four: }
      sentry_context[:claim_number] = claim_number if claim_number

      SentryLogging.log_exception_to_sentry(
        ex,
        sentry_context,
        { error: :check_in_va_notify_job, team: 'check-in' }
      )

      facility_type = determine_facility_type_from_template(template_id)
      log_failure_no_retry('Retries exhausted', { template_id:, facility_type: })
    end

    # Determines facility type based on template ID
    # @param template_id [String] The template ID
    # @return [String] 'oh' or 'cie'
    def self.determine_facility_type_from_template(template_id)
      if template_id == 'cie-failure-template-id' ||
         [Constants::CIE_FAILURE_TEMPLATE_ID, Constants::CIE_ERROR_TEMPLATE_ID,
          Constants::CIE_TIMEOUT_TEMPLATE_ID].include?(template_id)
        'cie'
      else
        'oh'
      end
    end

    def self.log_failure_no_retry(message, opts, logger_instance = Rails.logger)
      template_id = opts&.dig(:template_id) || (opts.is_a?(String) ? opts : nil)
      facility_type = opts&.dig(:facility_type)

      if FAILED_CLAIM_TEMPLATE_IDS.include?(template_id) ||
         template_id == 'oh-failure-template-id' ||
         template_id == 'cie-failure-template-id'

        facility_type = determine_facility_type_from_template(template_id) if facility_type.nil?

        tags = if facility_type == 'cie'
                 Constants::STATSD_CIE_SILENT_FAILURE_TAGS
               else
                 Constants::STATSD_OH_SILENT_FAILURE_TAGS
               end

        StatsD.increment(Constants::STATSD_NOTIFY_SILENT_FAILURE, tags:)
      end

      StatsD.increment(Constants::STATSD_NOTIFY_ERROR)
      failure_message = "#{message}, Won't Retry"
      log_send_sms_failure(failure_message, opts, logger_instance)

      # Explicit return here to be sure retry doesn't trigger.
      true
    end

    # Logs information about SMS sending failures
    #
    # @param error_message [String] Error message to log
    # @param opts [Hash] Options hash containing job parameters
    # @param logger_instance [Logger] Logger instance to use (defaults to Rails.logger for class method calls)
    # @return [void]
    #
    # NOTE: Don't increment StatsD failure yet, this occurs once the job has run through it's retries
    def self.log_send_sms_failure(error_message, opts, logger_instance = Rails.logger)
      phone_number = opts[:mobile_phone]
      phone_last_four = phone_number ? phone_number.delete('^0-9').last(4) : 'unknown'
      template_id = opts[:template_id]
      uuid = opts[:uuid]
      logger_instance.info({
                             message: "Failed to send Travel Claim Notification SMS for #{uuid}: #{error_message}",
                             template_id:,
                             phone_last_four:
                           })
    end

    private

    # Validates that all required fields are present
    #
    # @param opts [Hash] Options hash containing job parameters
    # @return [Boolean] true if all required fields are present, false otherwise
    def required_fields_valid?(opts)
      missing_fields = missing_required_fields(opts)

      return true if missing_fields.empty?

      error_message = "missing #{missing_fields.join(', ')}"
      self.class.log_failure_no_retry(error_message, opts, logger)
      false
    end

    # Checks for missing required fields and logs if any are missing
    #
    # @param opts [Hash] Options hash containing job parameters
    # @return [Array<String>] List of missing field names
    def missing_required_fields(opts)
      missing_fields = []
      REQUIRED_FIELDS.each do |field|
        missing_fields << field.to_s if opts&.dig(field).blank?
      end

      missing_fields
    end

    # Parses the appointment date string into a Date object
    # On failure, logs the error and increments failure metrics with custom tags
    #
    # @param date_string [String] Appointment date in YYYY-MM-DD format
    # @return [Date, nil] Parsed date if format is valid, nil otherwise
    def parse_appointment_date(opts)
      date_string = opts[:appointment_date]
      DateTime.strptime(date_string.to_s, '%Y-%m-%d').to_date
    rescue
      self.class.log_failure_no_retry('invalid appointment date format', opts, logger)
      nil
    end

    # Returns a configured instance of the VaNotify client
    #
    # @return [VaNotify::Service] Configured VaNotify client
    def notify_client
      @notify_client ||= VaNotify::Service.new(Settings.vanotify.services.check_in.api_key)
    end

    # Logs information about the notification attempt
    #
    # @param opts [Hash] Options hash containing job parameters
    # @return [void]
    def log_sending_travel_claim_notification(opts)
      phone_last_four = opts[:mobile_phone].delete('^0-9').last(4)
      template_id = opts[:template_id]
      uuid = opts[:uuid]

      log_message_and_context = {
        message: "Sending Travel Claim Notification SMS for #{uuid}",
        phone_last_four:,
        template_id:,
      }.compact

      logger.info(log_message_and_context)
    end

    # Sends the SMS notification using VaNotify service
    # Uses the parsed date and selects the appropriate sender ID based on facility type
    #
    # @param opts [Hash] Options hash containing job parameters - all required fields have been validated
    # @param parsed_date [Date] Parsed appointment date
    # @return [Object] The result from the VaNotify send_sms call
    def va_notify_send_sms(opts, parsed_date)
      formatted_date = parsed_date.strftime('%b %d')
      facility_type = opts&.dig(:facility_type)
      sms_sender_id = if facility_type && 'oh'.casecmp?(facility_type)
                        Constants::OH_SMS_SENDER_ID
                      else
                        Constants::CIE_SMS_SENDER_ID
                      end

      phone_number = opts[:mobile_phone]
      template_id = opts[:template_id]
      claim_number_last_four = opts[:claim_number_last_four].presence || 'unknown'
      personalisation = { claim_number: claim_number_last_four, appt_date: formatted_date }

      notify_client.send_sms(phone_number:, template_id:, sms_sender_id:, personalisation:)
    end

    # Logs information about successful SMS sending
    #
    # @param opts [Hash] Options hash containing job parameters
    # @return [void]
    def log_success(opts)
      phone_last_four = opts[:mobile_phone].delete('^0-9').last(4)
      template_id = opts[:template_id]
      uuid = opts[:uuid]
      logger.info({ message: "Successfully sent Travel Claim Notification SMS for #{uuid}",
                    template_id:,
                    phone_last_four: })
      StatsD.increment(Constants::STATSD_NOTIFY_SUCCESS)
    end
  end
end
