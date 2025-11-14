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
    include TravelClaimNotificationUtilities

    # 14 retries to span approximately 25 hours, this is to allow for unexpected outage of the
    # external messaging service. If the service is down for more than 25 hours, the job will
    # be sent to the dead queue where it can be manually retried once it is confirmed the service
    # is back up.
    sidekiq_options retry: 14
    REQUIRED_FIELDS = %i[phone_number template_id appointment_date].freeze

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
      phone_number = redis_client.patient_cell_phone(uuid:) || redis_client.mobile_phone(uuid:)
      opts = { phone_number:, appointment_date:, template_id:, claim_number_last_four:, uuid: }

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

    ##
    # Callback executed when all retries are exhausted
    #
    # @param job [Hash] The Sidekiq job hash containing job metadata
    # @param ex [Exception] The exception that caused the job to fail
    sidekiq_retries_exhausted do |job, ex|
      CheckIn::TravelClaimNotificationJob.handle_retries_exhausted(job, ex)
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
    def self.handle_retries_exhausted(job, ex)
      uuid = job.dig('args', 0)
      template_id = job.dig('args', 2)
      claim_number = job.dig('args', 3)

      redis_client = TravelClaim::RedisClient.build
      phone_number = redis_client.patient_cell_phone(uuid:) || redis_client.mobile_phone(uuid:)
      phone_last_four = extract_phone_last_four(phone_number)

      sentry_context = { template_id:, phone_last_four: }
      sentry_context[:claim_number] = claim_number if claim_number

      # Use logging helper for class method context
      logging_helper.log_exception_to_sentry(
        ex,
        sentry_context,
        { error: :check_in_va_notify_job, team: 'check-in' }
      )
      Rails.logger.error("Travel Claim Notification retries exhausted: #{ex.message} - Context: #{sentry_context}")

      facility_type = determine_facility_type_from_template(template_id)
      log_failure_no_retry('Retries exhausted', { uuid:, phone_number:, template_id:, facility_type: })
    end

    # Helper to enable logging in class method contexts
    # Vets::SharedLogging requires instance methods, so we create a temporary object
    def self.logging_helper
      @logging_helper ||= Class.new { include Vets::SharedLogging }.new # rubocop:disable ThreadSafety/ClassInstanceVariable
    end

    ##
    # Logs failure when retries are exhausted or not applicable
    #
    # Increments silent failure metrics and error metrics, then logs the failure message.
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
      phone_number = opts[:phone_number]
      phone_last_four = extract_phone_last_four(phone_number)
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

    ##
    # Validates that all required fields are present
    #
    # @param opts [Hash] Options hash containing mobile_phone, template_id, and appointment_date
    # @return [Boolean] true if all required fields are present, false otherwise
    def validate_and_log_missing_fields(opts)
      missing_fields = missing_required_fields(opts)

      return true if missing_fields.empty?

      error_message = "missing #{missing_fields.join(', ')}"
      self.class.log_failure_no_retry(error_message, opts)
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
      self.class.log_failure_no_retry('invalid appointment date format', opts)
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
      facility_type = determine_facility_type_from_template(template_id)

      message = 'Sending Travel Claim Notification SMS'
      log_data = self.class.build_log_data(message, opts, :info)
      self.class.log_with_context(:info, message, log_data)
      notify_client(build_callback_options(opts)).send_sms(
        phone_number: opts[:phone_number],
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
    # Builds callback options for VaNotify service
    #
    # @param opts [Hash] Options hash containing job parameters
    # @return [Hash] Callback configuration for VA Notify delivery status tracking
    def build_callback_options(opts)
      callback_options = {
        callback_metadata: {
          uuid: opts[:uuid],
          template_id: opts[:template_id],
          statsd_tags: {
            'service' => 'check-in',
            'function' => 'travel-claim-notification'
          }
        }
      }

      if Flipper.enabled?(:check_in_experience_travel_claim_notification_callback)
        callback_options[:callback_klass] = CheckIn::TravelClaimNotificationCallback
      end

      callback_options
    end
  end
end
