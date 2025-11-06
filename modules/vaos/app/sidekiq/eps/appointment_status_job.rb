# frozen_string_literal: true

module Eps
  ##
  # Sidekiq job responsible for checking appointment processing status and handling retries.
  #
  # This job monitors submitted appointments to ensure they complete successfully.
  # It periodically checks the appointment status and retries up to MAX_RETRIES times
  # if the appointment is still in a pending state. If maximum retries are reached
  # or an error occurs, it triggers an email notification to the user via the
  # AppointmentStatusEmailJob.
  #
  # The job implements a polling mechanism with exponential backoff to check
  # appointment completion status from the EPS (Enterprise Person Service).
  #
  # @example Enqueue the job
  #   Eps::AppointmentStatusJob.perform_async(user_uuid, appointment_id_last4)
  #
  # @example Enqueue with custom retry count
  #   Eps::AppointmentStatusJob.perform_async(user_uuid, appointment_id_last4, 1)
  #
  class AppointmentStatusJob
    include Sidekiq::Worker
    include VAOS::CommunityCareConstants

    STATSD_KEY = "#{STATSD_PREFIX}.appointment_status_check".freeze
    STATSD_FAILURE_METRIC = "#{STATSD_KEY}.failure".freeze
    ERROR_MESSAGE = 'Could not verify the booking status of your submitted appointment, ' \
                    'please contact support'
    MAX_RETRIES = 3

    ##
    # Main job execution method that processes appointment status checking.
    #
    # Fetches appointment data from Redis, validates it, and then checks the
    # appointment status via the EPS service. Implements retry logic for
    # pending appointments and error handling for failed operations.
    #
    # @param user_uuid [String] The UUID of the user associated with the appointment
    # @param appointment_id_last4 [String] The last 4 digits of the appointment ID for identification
    # @param retry_count [Integer] The current retry attempt count (default: 0)
    # @return [void]
    #
    def perform(user_uuid, appointment_id_last4, retry_count = 0)
      @user_uuid = user_uuid
      @appointment_id_last4 = appointment_id_last4

      appointment_data = fetch_and_validate_appointment_data
      return unless appointment_data

      appointment_id = appointment_data[:appointment_id]
      user = User.find(user_uuid)

      process_appointment_status(user, appointment_id, retry_count)
    end

    private

    ##
    # Fetches and validates appointment data from Redis cache.
    #
    # Retrieves cached appointment information and ensures all required fields
    # (appointment_id and email) are present. Logs errors and metrics for
    # missing or incomplete data scenarios.
    #
    # @return [Hash, nil] Appointment data hash if valid, nil if missing or invalid
    #
    def fetch_and_validate_appointment_data
      redis_client = Eps::RedisClient.new
      appointment_data = redis_client.fetch_appointment_data(uuid: @user_uuid, appointment_id: @appointment_id_last4)

      if appointment_data.nil? || appointment_data[:appointment_id].blank? || appointment_data[:email].blank?
        log_missing_redis_data(appointment_data)
        return nil
      end

      appointment_data
    end

    ##
    # Logs missing or incomplete Redis data with appropriate error tracking.
    #
    # Records detailed error information to Rails logger and increments StatsD
    # failure metrics when appointment data is missing or incomplete in Redis cache.
    #
    # @param appointment_data [Hash, nil] The appointment data that was retrieved (may be nil or incomplete)
    # @return [void]
    #
    def log_missing_redis_data(appointment_data)
      Rails.logger.error("#{CC_APPOINTMENTS}: #{self.class} missing or incomplete Redis data",
                         { user_uuid: @user_uuid, appointment_id_last4: @appointment_id_last4,
                           appointment_data: }.to_json)
      StatsD.increment(STATSD_FAILURE_METRIC, tags: [COMMUNITY_CARE_SERVICE_TAG])
    end

    ##
    # Processes appointment status checking with comprehensive error handling.
    #
    # Calls the EPS appointment service to check the current status of the appointment.
    # Handles service responses and any exceptions that may occur during the API call.
    # Triggers email notifications for service failures.
    #
    # @param user [User] The user object associated with the appointment
    # @param appointment_id [String] The full appointment ID to check
    # @param retry_count [Integer] Current retry attempt number
    # @return [void]
    #
    def process_appointment_status(user, appointment_id, retry_count)
      service = Eps::AppointmentService.new(user)
      begin
        response = service.get_appointment(appointment_id:)
        handle_appointment_response(response, retry_count)
      rescue
        Rails.logger.error("#{CC_APPOINTMENTS}: #{self.class} failed to get appointment status",
                           { user_uuid: @user_uuid, appointment_id_last4: @appointment_id_last4 })
        StatsD.increment(STATSD_FAILURE_METRIC, tags: [COMMUNITY_CARE_SERVICE_TAG])
        send_vanotify_message(error: ERROR_MESSAGE)
      end
    end

    ##
    # Handles appointment service response and determines next action.
    #
    # Analyzes the appointment response to determine if the appointment is complete,
    # needs more time to process (retry), or has exceeded maximum retry attempts.
    # Implements the retry logic with scheduled delays and failure notifications.
    #
    # @param response [Object] The response object from the EPS appointment service
    # @param retry_count [Integer] Current retry attempt number
    # @return [void]
    #
    def handle_appointment_response(response, retry_count)
      if appointment_finished?(response)
        StatsD.increment("#{STATSD_KEY}.success", tags: [COMMUNITY_CARE_SERVICE_TAG])
      elsif retry_count < MAX_RETRIES
        self.class.perform_in(1.minute, @user_uuid, @appointment_id_last4, retry_count + 1)
      else
        StatsD.increment(STATSD_FAILURE_METRIC, tags: [COMMUNITY_CARE_SERVICE_TAG])
        Rails.logger.error("#{CC_APPOINTMENTS}: #{self.class} could not confirm appointment booking",
                           { user_uuid: @user_uuid, appointment_id_last4: @appointment_id_last4 })
        send_vanotify_message(error: ERROR_MESSAGE)
      end
    end

    ##
    # Determines if an appointment has completed processing.
    #
    # Checks the appointment response to determine if the appointment has reached
    # a final state (either completed or booked). This is used to decide whether
    # to continue retrying or consider the appointment successfully processed.
    #
    # The method performs case-insensitive string comparisons to handle variations
    # in response formatting from external systems and safely handles nil values.
    #
    # @param response [Object] The response object from the appointment service containing
    #   state and appointmentDetails information
    # @return [Boolean] true if the appointment is finished (completed or booked), false otherwise
    #
    def appointment_finished?(response)
      response.state&.downcase == 'completed' || response.appointmentDetails&.status&.downcase == 'booked'
    end

    ##
    # Triggers email notification for appointment processing failures.
    #
    # Enqueues an AppointmentStatusEmailJob to send failure notification emails
    # to users when appointment processing fails or exceeds maximum retry attempts.
    # This provides users with timely feedback about appointment booking issues.
    #
    # @param error [String, nil] The error message to include in the notification email (default: nil)
    # @return [void]
    #
    def send_vanotify_message(error: nil)
      Eps::AppointmentStatusEmailJob.perform_async(@user_uuid, @appointment_id_last4, error)
    end
  end
end
