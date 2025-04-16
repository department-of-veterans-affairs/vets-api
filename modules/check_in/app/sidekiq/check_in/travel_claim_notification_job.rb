# frozen_string_literal: true

module CheckIn
  # Sidekiq job responsible for sending SMS notifications related to travel claims.
  # This job handles sending text messages to users via VaNotify service,
  # including error handling, retries, and logging.
  #
  # @example Enqueue the job with required parameters
  #   CheckIn::TravelClaimNotificationJob.perform_async({
  #     mobile_phone: '202-555-0123',         # Required
  #     appointment_date: '2023-05-15',       # Required
  #     template_id: 'template-id-123',       # Required
  #     claim_number: '1234',                 # Required
  #     facility_type: 'oh'                   # Optional - defaults to 'cie' when nil or not 'oh'
  #   })
  class TravelClaimNotificationJob < TravelClaimBaseJob
    # Maximum number of retry attempts before the job is considered exhausted
    MAX_RETRIES = 12
    sidekiq_options retry: MAX_RETRIES

    REQUIRED_FIELDS = %i[mobile_phone template_id appointment_date].freeze

    # Performs the job of sending an SMS notification via VaNotify
    #
    # Validates input parameters, logs the attempt, and handles success/failure
    # metrics. Returns early if required parameters like mobile_phone are missing.
    #
    # @param opts [Hash] Options hash containing parameters for the notification
    # @option opts [String] :mobile_phone The phone number to send the SMS to (required)
    # @option opts [String] :appointment_date The appointment date in YYYY-MM-DD format (required)
    # @option opts [String] :template_id The VaNotify template ID to use (required)
    # @option opts [String] :claim_number The claim number to include in the message (required)
    # @option opts [String] :facility_type The facility type ('oh' or 'cie'). Optional, defaults to 'cie' when nil.
    # @return [void]
    def perform(opts = {})
      return self.class.log_failure(opts) unless validate_required_fields(opts)

      parsed_date = parse_appointment_date(opts[:appointment_date])
      return self.class.log_failure(opts) unless parsed_date

      log_sending_travel_claim_notification(opts)
      attempt_number = current_attempt_number

      begin
        va_notify_send_sms(opts, parsed_date)
        StatsD.increment(Constants::STATSD_NOTIFY_SUCCESS)
      rescue => e
        log_send_sms_failure(attempt_number)
        raise e
      end
    end

    # Callback executed when all retries are exhausted
    # @param job [Hash] The Sidekiq job hash containing job metadata
    # @param ex [Exception] The exception that caused the job to fail
    sidekiq_retries_exhausted do |job, ex|
      CheckIn::TravelClaimNotificationJob.handle_error(job, ex)
    end

    # Handles errors after all retries have been exhausted
    # Logs the error to Sentry and updates metrics based on the template type and facility
    #
    # @param job [Hash] The Sidekiq job hash containing job metadata
    # @param ex [Exception] The exception that caused the job to fail
    # @return [void]
    def self.handle_error(job, ex)
      opts = job.dig('args', 0) || {}

      SentryLogging.log_exception_to_sentry(
        ex,
        {
          phone_number: phone_last_four(opts),
          template_id: opts&.dig(:template_id),
          claim_number: opts&.dig(:claim_number).presence&.last(4)
        },
        { error: :check_in_va_notify_job, team: 'check-in' }
      )
      log_failure(opts)
    end

    # Extracts the last four digits of a phone number from a hash
    # Removes any non-numeric characters before extracting the last four digits
    #
    # @param hash [Hash, nil] Hash containing a :mobile_phone key
    # @return [String, nil] Last four digits of the phone number, or nil if not present
    def self.phone_last_four(hash)
      hash&.dig(:mobile_phone)&.delete('^0-9')&.last(4)
    end

    def self.log_failure(opts)
      if FAILED_CLAIM_TEMPLATE_IDS.include?(opts&.dig(:template_id))
        tags = if opts&.dig(:facility_type) == 'cie'
                 Constants::STATSD_CIE_SILENT_FAILURE_TAGS
               else
                 Constants::STATSD_OH_SILENT_FAILURE_TAGS
               end
        StatsD.increment(Constants::STATSD_NOTIFY_SILENT_FAILURE, tags:)
      end

      StatsD.increment(Constants::STATSD_NOTIFY_ERROR)
      nil
    end

    private

    # Validates that all required fields are present
    #
    # @param opts [Hash] Options hash containing job parameters
    # @return [Boolean] true if all required fields are present, false otherwise
    def validate_required_fields(opts)
      missing_fields = missing_required_fields(opts)
      missing_fields.empty?
    end

    # Checks for missing required fields and logs if any are missing
    #
    # @param opts [Hash] Options hash containing job parameters
    # @return [Array<String>] List of missing field names
    def missing_required_fields(opts)
      missing_data = []
      REQUIRED_FIELDS.each do |field|
        missing_data << field.to_s if opts&.dig(field).blank?
      end
      log_missing_fields(missing_data) if missing_data.any?
      missing_data
    end

    # Logs information about missing fields and increments failure metrics
    #
    # @param missing_data [Array<String>] List of missing field names
    # @return [void]
    def log_missing_fields(missing_data)
      missing_data = missing_data.join(', ')
      logger.info({ message: "TravelClaimNotificationJob failed without retry: missing #{missing_data}" })
    end

    # Parses the appointment date string into a Date object
    # On failure, logs the error and increments failure metrics with custom tags
    #
    # @param date_string [String] Appointment date in YYYY-MM-DD format
    # @return [Date, nil] Parsed date if format is valid, nil otherwise
    def parse_appointment_date(date_string)
      DateTime.strptime(date_string.to_s, '%Y-%m-%d').to_date
    rescue
      logger.info({ message: 'TravelClaimNotificationJob failed without retry: invalid appointment date format' })

      # return nil to end job without retrying
      nil
    end

    # Calculates the current attempt number based on Sidekiq retry count
    #
    # @return [Integer] The current attempt number (1-based)
    def current_attempt_number
      retry_attempt = 0
      if self.class.sidekiq_options_hash&.[]('retry_count')
        retry_attempt = self.class.sidekiq_options_hash['retry_count'].to_i
      end
      retry_attempt + 1
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
      phone_last_four = self.class.phone_last_four(opts)
      template_id = opts[:template_id]

      log_message_and_context = {
        message: "Sending travel claim notification to #{phone_last_four}, #{template_id}",
        phone_last_four:,
        template_id:
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
      claim_number = opts[:claim_number].presence
      personalisation = { claim_number:, appt_date: formatted_date }

      notify_client.send_sms(phone_number:, template_id:, sms_sender_id:, personalisation:)
    end

    # Logs information about SMS sending failures
    #
    # @param attempt_number [Integer] The current attempt number
    # @return [void]
    def log_send_sms_failure(attempt_number)
      logger.info({ message: "TravelClaimNotificationJob failed, attempt #{attempt_number} of #{MAX_RETRIES + 1}" })
    end
  end
end
