# frozen_string_literal: true

module TravelClaim
  ##
  # Service for submitting travel claims through the Travel Pay API.
  # Handles the complete synchronous flow: appointment lookup/creation,
  # claim creation, expense addition, and claim submission.
  #
  # @example
  #   service = ClaimSubmissionService.new(
  #     check_in: session,
  #     appointment_date: '2024-01-15T10:00:00Z',
  #     facility_type: 'vamc',
  #     uuid: 'user-uuid'
  #   )
  #   result = service.submit_claim
  #
  class ClaimSubmissionService
    attr_reader :check_in, :appointment_date, :facility_type, :uuid

    ##
    # Initialize the service with required parameters.
    #
    # @param check_in [CheckIn::V2::Session] authenticated session
    # @param appointment_date [String] ISO 8601 formatted appointment date
    # @param facility_type [String] facility type ('oh' or 'vamc')
    # @param uuid [String] user UUID from request parameters
    #
    def initialize(check_in:, appointment_date:, facility_type:, uuid:)
      @check_in = check_in
      @appointment_date = appointment_date
      @facility_type = facility_type
      @uuid = uuid
    end

    ##
    # Submits a travel claim for processing through the Travel Pay API.
    # Validates parameters, then executes the complete claim submission flow.
    #
    # @return [Hash] success response with claim ID and notification data
    # @raise [Common::Exceptions::BackendServiceException] for API failures
    # @raise [ArgumentError] for validation failures
    #
    def submit_claim
      validate_parameters
      result = process_claim_submission

      # Send notification if feature flag is enabled
      send_notification_if_enabled if result['success']

      result
    rescue Common::Exceptions::BackendServiceException => e
      # Send error notification if feature flag is enabled
      send_error_notification_if_enabled(e)
      raise e
    rescue => e
      log_message(:error, 'Unexpected error', error_class: e.class.name)
      # Send error notification if feature flag is enabled
      send_error_notification_if_enabled(e)
      raise e
    end

    private

    ##
    # Executes the complete claim submission workflow.
    #
    # @return [Hash] success response with claim ID
    # @raise [Common::Exceptions::BackendServiceException] for API failures
    #
    def process_claim_submission
      log_message(:info, 'Travel claim transaction START')
      appointment_id = get_appointment_id
      claim_id = create_new_claim(appointment_id)
      add_expense_to_claim(claim_id)
      submission_response = submit_claim_for_processing(claim_id)

      # Extract claim data from submission response for notifications
      @claim_number_last_four = extract_claim_number_last_four(submission_response)

      { 'success' => true, 'claimId' => claim_id }
    end

    ##
    # Validates required parameters are present and not blank.
    #
    # @raise [Common::Exceptions::BackendServiceException] if any required parameter is missing
    #
    def validate_parameters
      raise_backend_service_exception('CheckIn object is required', 400, 'VA901') if @check_in.nil?
      raise_backend_service_exception('Appointment date is required', 400, 'VA902') if @appointment_date.blank?
      raise_backend_service_exception('Facility type is required', 400, 'VA903') if @facility_type.blank?
      raise_backend_service_exception('Uuid is required', 400, 'VA904') if @uuid.blank?

      # Initialize date fields early so they're available for error notifications
      appointment_date_yyyy_mm_dd
    end

    def normalized_appointment_datetime
      @normalized_appointment_datetime ||= begin
        # Require a time component (e.g., "T10:00:00")
        unless @appointment_date.is_a?(String) && @appointment_date.include?('T')
          raise_backend_service_exception(
            'Appointment date must include a time component (e.g., 2025-09-16T10:00:00Z)',
            400,
            'VA905'
          )
        end

        t_utc = TravelPay::DateUtils.strip_timezone(@appointment_date)
        t_utc.iso8601 # "YYYY-MM-DDTHH:MM:SSZ"
      rescue
        raise_backend_service_exception(
          'Appointment date must be a valid ISO 8601 date-time (e.g., 2025-09-16T10:00:00Z)',
          400,
          'VA905'
        )
      end
    end

    def appointment_date_yyyy_mm_dd
      @appointment_date_yyyy_mm_dd ||= Time.iso8601(normalized_appointment_datetime).to_date.iso8601
    end

    ##
    # Retrieves or creates an appointment ID for the given date and facility.
    #
    # @return [String] appointment ID
    # @raise [Common::Exceptions::BackendServiceException] if appointment not found/created
    #
    def get_appointment_id
      log_message(:info, 'Get appointment ID', uuid: @uuid)

      response = client.send_appointment_request
      appointment_id = response.body.dig('data', 0, 'id')

      unless appointment_id
        raise_backend_service_exception('Appointment could not be found or created', response.status)
      end

      appointment_id
    end

    ##
    # Creates a new travel claim for the given appointment.
    #
    # @param appointment_id [String] the appointment ID
    # @return [String] claim ID
    # @raise [Common::Exceptions::BackendServiceException] if claim creation fails
    #
    def create_new_claim(appointment_id)
      log_message(:info, 'Create claim', uuid: @uuid)

      response = client.send_claim_request(appointment_id:)
      claim_id = response.body.dig('data', 'claimId')

      raise_backend_service_exception('Failed to create claim', response.status) unless claim_id

      claim_id
    end

    ##
    # Adds a mileage expense to the claim for the appointment date.
    #
    # @param claim_id [String] the claim ID
    # @raise [Common::Exceptions::BackendServiceException] if expense addition fails
    #
    def add_expense_to_claim(claim_id)
      log_message(:info, 'Add expense to claim', uuid: @uuid)

      response = client.send_mileage_expense_request(
        claim_id:,
        date_incurred: appointment_date_yyyy_mm_dd
      )

      raise_backend_service_exception('Failed to add expense', response.status) unless response.status == 200
    end

    ##
    # Submits the claim for final processing.
    #
    # @param claim_id [String] the claim ID
    # @return [Faraday::Response] the submission response
    # @raise [Common::Exceptions::BackendServiceException] if submission fails
    #
    def submit_claim_for_processing(claim_id)
      log_message(:info, 'Submit claim', uuid: @uuid)

      response = client.send_claim_submission_request(claim_id:)

      raise_backend_service_exception('Failed to submit claim', response.status) unless response.status == 200

      response
    end

    ##
    # Returns a configured TravelPayClient instance.
    #
    # @return [TravelClaim::TravelPayClient] configured client
    #
    def client
      @client ||= TravelClaim::TravelPayClient.new(
        uuid: @uuid,
        appointment_date_time: normalized_appointment_datetime,
        check_in_uuid: @check_in.uuid
      )
    end

    ##
    # Logs a message with standard claim submission context.
    #
    # @param level [Symbol] log level (:info, :error, etc.)
    # @param message [String] log message
    # @param additional_data [Hash] additional data to include in log
    #
    def log_message(level, message, additional_data = {})
      return unless Flipper.enabled?(:check_in_experience_travel_claim_logging)

      log_data = {
        message: "CIE Travel Claim Submission: #{message}",
        facility_type: @facility_type,
        check_in_uuid: @uuid
      }.merge(additional_data)

      Rails.logger.public_send(level, log_data)
    end

    ##
    # Raises a BackendServiceException with the given error message and status code
    #
    # @param detail [String] the error detail message
    # @param status [Integer] the HTTP status code (defaults to 502)
    # @param code [String] the error code (defaults to 'VA900')
    #
    def raise_backend_service_exception(detail, status = 502, code = 'VA900')
      raise Common::Exceptions::BackendServiceException.new(
        code,
        { detail: },
        status
      )
    end

    ##
    # Extracts the last four digits of the claim number from API response
    #
    # @param response [Faraday::Response] the API response
    # @return [String] last four digits of claim ID, or 'unknown' if not found
    #
    def extract_claim_number_last_four(response)
      response_body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
      claim_id = response_body.dig('data', 'claimId')
      claim_id&.last(4) || 'unknown'
    rescue => e
      log_message(:error, 'Failed to extract claim number', error: e.message)
      'unknown'
    end

    ##
    # Sends a success notification if feature flag is enabled
    #
    def send_notification_if_enabled
      return unless notification_enabled?

      template_id = success_template_id
      claim_number_last_four = @claim_number_last_four

      log_message(:info, 'Sending success notification',
                  template_id:, claim_last_four: claim_number_last_four)

      CheckIn::TravelClaimNotificationJob.perform_async(
        @uuid,
        @appointment_date_yyyy_mm_dd,
        template_id,
        claim_number_last_four
      )
    end

    ##
    # Sends an error notification if feature flag is enabled
    #
    # @param error [Exception] the error that occurred
    #
    def send_error_notification_if_enabled(error)
      return unless notification_enabled?

      template_id = determine_error_template_id(error)
      claim_number_last_four = @claim_number_last_four || 'unknown'

      log_message(:info, 'Sending error notification',
                  template_id:, error_class: error.class.name)

      CheckIn::TravelClaimNotificationJob.perform_async(
        @uuid,
        @appointment_date_yyyy_mm_dd,
        template_id,
        claim_number_last_four
      )
    end

    ##
    # Determines if notifications are enabled via feature flag
    # Uses the same flag as V1 travel reimbursement feature
    #
    # @return [Boolean] true if notifications should be sent
    #
    def notification_enabled?
      Flipper.enabled?(:check_in_experience_travel_reimbursement)
    end

    ##
    # Returns the appropriate success template ID based on facility type
    #
    # @return [String] template ID for success notifications
    #
    def success_template_id
      if @facility_type&.downcase == 'oh'
        CheckIn::Constants::OH_SUCCESS_TEMPLATE_ID
      else
        CheckIn::Constants::CIE_SUCCESS_TEMPLATE_ID
      end
    end

    ##
    # Returns the appropriate error template ID based on facility type
    #
    # @return [String] template ID for error notifications
    #
    def error_template_id
      if @facility_type&.downcase == 'oh'
        CheckIn::Constants::OH_ERROR_TEMPLATE_ID
      else
        CheckIn::Constants::CIE_ERROR_TEMPLATE_ID
      end
    end

    ##
    # Determines the appropriate error template ID based on the error type
    #
    def determine_error_template_id(error)
      if error.is_a?(Common::Exceptions::BackendServiceException) &&
         error.response_values[:detail]&.include?('already been created')
        @facility_type&.downcase == 'oh' ? CheckIn::Constants::OH_DUPLICATE_TEMPLATE_ID : CheckIn::Constants::CIE_DUPLICATE_TEMPLATE_ID
      else
        error_template_id
      end
    end
  end
end
