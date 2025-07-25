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
    # Validates input parameters, parses the appointment date, and sends the SMS.
    # Returns early if required parameters are missing or date parsing fails.
    # Logs success or failure messages and handles retries via exception re-raising.
    #
    # @param uuid [String] The appointment UUID used to retrieve data from Redis
    # @param appointment_date [String] The appointment date in YYYY-MM-DD format
    # @param template_id [String] The VaNotify template ID to use
    # @param claim_number_last_four [String] The last four digits of claim number
    # @return [void]
    def perform(uuid, appointment_date, template_id, claim_number_last_four)
      redis_client = TravelClaim::RedisClient.build
      mobile_phone = redis_client.patient_cell_phone(uuid:) || redis_client.mobile_phone(uuid:)
      facility_type = redis_client.facility_type(uuid:)
      opts = { mobile_phone:, appointment_date:, template_id:, facility_type:, claim_number_last_four:, uuid: }

      # Early return here because there is no sense in retrying if the required fields are missing
      return unless validate_and_log_missing_fields(opts)
      return unless (parsed_date = parse_appointment_date(opts))

      begin
        va_notify_send_sms(opts, parsed_date)
      rescue => e
        message = "Failed to send Travel Claim Notification SMS: #{e.message}"
        log_data = self.class.build_log_data(message, opts, :error)
        self.class.log_with_context(:error, message, log_data)

        # Explicit re-raise to trigger the retry mechanism
        raise e
      end

      # Log API request success (not delivery success - that would require VA Notify callbacks)
      message = 'Travel Claim Notification SMS API request succeeded'
      log_data = self.class.build_log_data(message, opts, :info)
      self.class.log_with_context(:info, message, log_data)
      StatsD.increment(Constants::STATSD_NOTIFY_SUCCESS)
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

    # Logs failure when retries are exhausted or not applicable
    # Increments appropriate StatsD metrics based on template type and logs the failure message.
    # Used for permanent failures that should not trigger retries.
    #
    # @param message [String] The failure message to log
    # @param opts [Hash] Options hash containing job parameters
    # @return [Boolean] Always returns false to prevent retries
    def self.log_failure_no_retry(message, opts)
      template_id = opts&.dig(:template_id)
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
        # Log silent failures as per Watchtower group as per silent failure policy
        StatsD.increment(Constants::STATSD_NOTIFY_SILENT_FAILURE, tags:)
      end

      # Log all failures for CIE team metrics tracking
      StatsD.increment(Constants::STATSD_NOTIFY_ERROR)
      failure_message = "Failed to send Travel Claim Notification SMS: #{message}, Won't Retry"
      log_data = build_log_data(failure_message, opts, :error)
      log_with_context(:error, failure_message, log_data)

      # Explicit return here to be sure retry doesn't trigger.
      false
    end

    # Builds log data for SMS sending attempts
    # For error logs: includes UUID along with other data
    # For info logs: includes template ID and phone last four digits (NO UUID)
    #
    # @param message [String] The log message (success or failure message)
    # @param opts [Hash] Options hash containing job parameters
    # @param log_level [Symbol] The log level to use (:info, :error, etc.) (defaults to :info)
    # @return [Hash] The log data hash
    def self.build_log_data(message, opts, log_level = :info)
      status = determine_status(message, log_level)

      log_data = { status: }
      log_data[:uuid] = opts[:uuid] if log_level == :error
      phone_number = opts[:mobile_phone]
      phone_last_four = phone_number ? phone_number.delete('^0-9').last(4) : 'unknown'
      log_data[:template_id] = opts[:template_id]
      log_data[:phone_last_four] = phone_last_four

      log_data
    end

    # Determines the appropriate status based on message content and log level
    # @param message [String] The log message
    # @param log_level [Symbol] The log level
    # @return [String] The status
    def self.determine_status(message, log_level)
      if log_level == :error
        if message.include?("Won't Retry")
          'failed_no_retry'
        else
          'failed'
        end
      elsif message.include?('Sending')
        'sending'
      elsif message.include?('succeeded')
        'success'
      else
        'info'
      end
    end

    private

    # Validates that all required fields are present
    #
    # @param opts [Hash] Options hash containing job parameters
    # @return [Boolean] true if all required fields are present, false otherwise
    def validate_and_log_missing_fields(opts)
      missing_fields = missing_required_fields(opts)

      return true if missing_fields.empty?

      error_message = "missing #{missing_fields.join(', ')}"
      self.class.log_failure_no_retry(error_message, opts)
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
    # @param opts [Hash] Options hash containing the appointment_date field
    # @return [Date, nil] Parsed date if format is valid, nil otherwise
    def parse_appointment_date(opts)
      date_string = opts[:appointment_date]
      DateTime.strptime(date_string.to_s, '%Y-%m-%d').to_date
    rescue
      self.class.log_failure_no_retry('invalid appointment date format', opts)
      nil
    end

    # Returns a configured instance of the VaNotify client
    #
    # @return [VaNotify::Service] Configured VaNotify client
    def notify_client
      @notify_client ||= VaNotify::Service.new(Settings.vanotify.services.check_in.api_key)
    end

    # Sends the SMS notification using VaNotify service
    # Logs the sending attempt, formats the date, selects the appropriate sender ID based on facility type,
    # and calls the VaNotify service to send the SMS.
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

      message = 'Sending Travel Claim Notification SMS'
      log_data = self.class.build_log_data(message, opts, :info)
      self.class.log_with_context(:info, message, log_data)
      notify_client.send_sms(phone_number:, template_id:, sms_sender_id:, personalisation:)
    end
  end
end
