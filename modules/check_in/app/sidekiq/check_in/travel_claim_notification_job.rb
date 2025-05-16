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
    REQUIRED_FIELDS = %i[mobile_phone template_id appointment_date claim_number_last_four].freeze

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
        claim_number_last_four:
      }

      return self.class.log_failure(opts) unless validate_required_fields(opts)

      log_sending_travel_claim_notification(opts)

      begin
        parsed_date = parse_appointment_date(opts[:appointment_date])
        return self.class.log_failure(opts) if parsed_date.nil?

        va_notify_send_sms(opts, parsed_date)
        StatsD.increment(Constants::STATSD_NOTIFY_SUCCESS)
      rescue => e
        log_send_sms_failure(e.message, opts)
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
    # Logs the error to Sentry and updates metrics based on the template type and facility.
    # The UUID and template ID are extracted from job arguments, and additional data like
    # phone number and claim number are retrieved from Redis.
    #
    # @param job [Hash] The Sidekiq job hash containing job metadata
    # @param ex [Exception] The exception that caused the job to fail
    # @return [void]
    def self.handle_error(job, ex)
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
      log_failure({ template_id:, facility_type: })
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

    def self.log_failure(opts)
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
      claim_number_last_four = opts[:claim_number_last_four].presence
      personalisation = { claim_number: claim_number_last_four, appt_date: formatted_date }

      notify_client.send_sms(phone_number:, template_id:, sms_sender_id:, personalisation:)
    end

    # Logs information about SMS sending failures
    #
    # @param error_message [String] Error message to log
    # @param opts [Hash] Options hash containing job parameters
    # @return [void]
    def log_send_sms_failure(error_message, opts)
      phone_last_four = opts[:mobile_phone].delete('^0-9').last(4)
      logger.info({ message: "Failed to send SMS to #{phone_last_four}: #{error_message}" })
    end
  end
end
