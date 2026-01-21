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
    attr_reader :appointment_date, :facility_type, :check_in_uuid

    CODE_CLAIM_EXISTS = TravelClaim::Response::CODE_CLAIM_EXISTS
    APPOINTMENT_ERROR = 'appointment_error'
    CLAIM_CREATE_ERROR = 'claim_create_error'
    EXPENSE_ADD_ERROR = 'expense_add_error'
    CLAIM_SUBMIT_ERROR = 'claim_submit_error'
    ERROR_METRICS = {
      APPOINTMENT_ERROR => {
        cie: CheckIn::Constants::CIE_STATSD_APPOINTMENT_ERROR,
        oh: CheckIn::Constants::OH_STATSD_APPOINTMENT_ERROR
      },
      CLAIM_CREATE_ERROR => {
        cie: CheckIn::Constants::CIE_STATSD_CLAIM_CREATE_ERROR,
        oh: CheckIn::Constants::OH_STATSD_CLAIM_CREATE_ERROR
      },
      EXPENSE_ADD_ERROR => {
        cie: CheckIn::Constants::CIE_STATSD_EXPENSE_ADD_ERROR,
        oh: CheckIn::Constants::OH_STATSD_EXPENSE_ADD_ERROR
      },
      CLAIM_SUBMIT_ERROR => {
        cie: CheckIn::Constants::CIE_STATSD_CLAIM_SUBMIT_ERROR,
        oh: CheckIn::Constants::OH_STATSD_CLAIM_SUBMIT_ERROR
      }
    }.freeze

    ##
    # Initialize the service with required parameters.
    #
    # @param appointment_date [String] ISO 8601 formatted appointment date
    # @param facility_type [String] facility type ('oh' or 'vamc')
    # @param check_in_uuid [String] check-in UUID from request parameters
    #
    def initialize(appointment_date:, facility_type:, check_in_uuid:)
      @appointment_date = appointment_date
      @facility_type = facility_type
      @check_in_uuid = check_in_uuid
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
      log_submission_start
      validate_parameters
      result = process_claim_submission

      log_submission_success(result)
      # Send notification if feature flag is enabled
      send_notification_if_enabled if result['success']

      result
    rescue Common::Exceptions::BackendServiceException => e
      log_submission_failure(error: e)
      # Increment general failure metric
      increment_failure_metric
      # Check if this is a duplicate claim error
      handle_duplicate_claim_error if duplicate_claim_error?(e)
      # Send error notification if feature flag is enabled
      send_error_notification_if_enabled(e)
      raise e
    rescue => e
      log_submission_failure(error: e)
      # Increment general failure metric
      increment_failure_metric
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
      @current_step = 'get_appointment'
      appointment_id = get_appointment_id

      @current_step = 'create_claim'
      claim_id = create_new_claim(appointment_id)

      @current_step = 'add_expense'
      add_expense_to_claim(claim_id)

      @current_step = 'submit_claim'
      submission_response = submit_claim_for_processing(claim_id)

      # Extract claim data from submission response for notifications
      @claim_number_last_four = extract_claim_number_last_four(submission_response)

      # Increment success metric
      increment_success_metric

      { 'success' => true, 'claimId' => claim_id }
    end

    ##
    # Validates required parameters are present and not blank.
    #
    # @raise [Common::Exceptions::BackendServiceException] if any required parameter is missing
    #
    def validate_parameters
      raise_backend_service_exception('Appointment date is required', 400, 'VA902') if @appointment_date.blank?
      raise_backend_service_exception('Facility type is required', 400, 'VA903') if @facility_type.blank?
      raise_backend_service_exception('Check-in UUID is required', 400, 'VA904') if @check_in_uuid.blank?

      # Initialize date fields early so they're available for error notifications
      normalized_appointment_datetime
      appointment_date_yyyy_mm_dd
    end

    def normalized_time_utc
      @normalized_time_utc ||= begin
        s = @appointment_date

        unless s.is_a?(String) && s.include?('T')
          raise_backend_service_exception(
            'Appointment date must include a time component (e.g., 2025-09-16T10:00:00Z)',
            400, 'VA905'
          )
        end

        # Strict ISO8601 parsing; raises ArgumentError on bad input.
        t = Time.iso8601(s)

        # Rebuild as UTC using the same wall-clock fields (ignores original offset).
        Time.utc(t.year, t.month, t.day, t.hour, t.min, t.sec)
      rescue ArgumentError
        raise_backend_service_exception(
          'Appointment date must be a valid ISO 8601 date-time (e.g., 2025-09-16T10:00:00Z)',
          400, 'VA905'
        )
      end
    end

    # Full ISO8601 with Z for API calls
    def normalized_appointment_datetime
      @normalized_appointment_datetime ||= normalized_time_utc.iso8601
    end

    # YYYY-MM-DD for expense date & notifications
    def appointment_date_yyyy_mm_dd
      @appointment_date_yyyy_mm_dd ||= normalized_time_utc.to_date.iso8601
    end

    ##
    # Retrieves or creates an appointment ID for the given date and facility.
    #
    # @return [String] appointment ID
    # @raise [Common::Exceptions::BackendServiceException] if appointment not found/created
    #
    def get_appointment_id
      response = client.send_appointment_request
      appointment_id = response.body.dig('data', 0, 'id')

      unless appointment_id
        increment_error_metric(APPOINTMENT_ERROR)
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
      response = client.send_claim_request(appointment_id:)
      claim_id = response.body.dig('data', 'claimId')

      unless claim_id
        increment_error_metric(CLAIM_CREATE_ERROR)
        raise_backend_service_exception('Failed to create claim', response.status)
      end

      claim_id
    end

    ##
    # Adds a mileage expense to the claim for the appointment date.
    #
    # @param claim_id [String] the claim ID
    # @raise [Common::Exceptions::BackendServiceException] if expense addition fails
    #
    def add_expense_to_claim(claim_id)
      response = client.send_mileage_expense_request(
        claim_id:,
        date_incurred: appointment_date_yyyy_mm_dd
      )

      unless response.status == 200
        increment_error_metric(EXPENSE_ADD_ERROR)
        raise_backend_service_exception('Failed to add expense', response.status)
      end
    end

    ##
    # Submits the claim for final processing.
    #
    # @param claim_id [String] the claim ID
    # @return [Faraday::Response] the submission response
    # @raise [Common::Exceptions::BackendServiceException] if submission fails
    #
    def submit_claim_for_processing(claim_id)
      response = client.send_claim_submission_request(claim_id:)

      unless response.status == 200
        increment_error_metric(CLAIM_SUBMIT_ERROR)
        raise_backend_service_exception('Failed to submit claim', response.status)
      end

      response
    end

    ##
    # Returns a configured TravelPayClient instance.
    #
    # @return [TravelClaim::TravelPayClient] configured client
    #
    def client
      @client ||= TravelClaim::TravelPayClient.new(
        check_in_uuid: @check_in_uuid,
        appointment_date_time: normalized_appointment_datetime,
        facility_type: @facility_type
      )
    end

    ##
    # Logs the start of a travel claim submission process.
    #
    def log_submission_start
      return unless Flipper.enabled?(:check_in_experience_travel_claim_logging)

      Rails.logger.info({
                          message: 'Travel Claim Submission: START',
                          facility_type: @facility_type,
                          check_in_uuid: @check_in_uuid
                        })
    end

    ##
    # Logs successful completion of travel claim submission.
    #
    # @param result [Hash] submission result containing claim data
    #
    def log_submission_success(result)
      return unless Flipper.enabled?(:check_in_experience_travel_claim_logging)

      Rails.logger.info({
                          message: 'Travel Claim Submission: SUCCESS',
                          facility_type: @facility_type,
                          check_in_uuid: @check_in_uuid,
                          claim_id: result['claimId']
                        })
    end

    ##
    # Logs failure of travel claim submission with step context.
    #
    # @param error [Exception] the error that caused the failure
    #
    def log_submission_failure(error:)
      return unless Flipper.enabled?(:check_in_experience_travel_claim_logging)

      Rails.logger.error({
                           message: 'Travel Claim Submission: FAILURE',
                           facility_type: @facility_type,
                           check_in_uuid: @check_in_uuid,
                           failed_step: @current_step || 'unknown',
                           error_class: error.class.name
                         })
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
      if Flipper.enabled?(:check_in_experience_travel_claim_logging)
        Rails.logger.error('Travel Claim: Failed to extract claim number',
                           error: e.message)
      end
      'unknown'
    end

    ##
    # Sends a success notification if feature flag is enabled
    #
    def send_notification_if_enabled
      return unless notification_enabled?

      template_id = success_template_id
      claim_number_last_four = @claim_number_last_four

      if Flipper.enabled?(:check_in_experience_travel_claim_logging)
        Rails.logger.info({
                            message: 'Travel Claim: Sending success notification',
                            template_id:,
                            claim_last_four: claim_number_last_four
                          })
      end

      CheckIn::TravelClaimNotificationJob.perform_async(
        @check_in_uuid,
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

      if Flipper.enabled?(:check_in_experience_travel_claim_logging)
        Rails.logger.info({
                            message: 'Travel Claim: Sending error notification',
                            template_id:,
                            error_class: error.class.name
                          })
      end

      CheckIn::TravelClaimNotificationJob.perform_async(
        @check_in_uuid,
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

    ##
    # Increments the appropriate success metric based on facility type
    #
    def increment_success_metric
      increment_metric_by_facility_type(
        CheckIn::Constants::CIE_STATSD_BTSSS_SUCCESS,
        CheckIn::Constants::OH_STATSD_BTSSS_SUCCESS
      )
    end

    ##
    # Increments the general failure metric based on facility type
    #
    def increment_failure_metric
      increment_metric_by_facility_type(
        CheckIn::Constants::CIE_STATSD_BTSSS_CLAIM_FAILURE,
        CheckIn::Constants::OH_STATSD_BTSSS_CLAIM_FAILURE
      )
    end

    ##
    # Increments the appropriate error metric based on facility type
    #
    # @param metric_type [String] the metric type constant
    #
    def increment_error_metric(metric_type)
      facility_key = @facility_type&.downcase == 'oh' ? :oh : :cie
      metric = ERROR_METRICS.dig(metric_type, facility_key)

      StatsD.increment(metric) if metric
    end

    ##
    # Checks if the error indicates a duplicate claim based on response code
    #
    # @param error [Common::Exceptions::BackendServiceException] the error to check
    # @return [Boolean] true if this is a duplicate claim error
    #
    def duplicate_claim_error?(error)
      # Check if the error detail contains the standardized duplicate claim code
      error.response_values[:detail]&.include?(CODE_CLAIM_EXISTS) ||
        # Fallback to string matching for backward compatibility
        error.response_values[:detail]&.include?('already been created') ||
        error.response_values[:detail]&.include?('already exists') ||
        error.response_values[:detail]&.include?('duplicate')
    end

    ##
    # Handles duplicate claim error by incrementing the appropriate metric
    #
    def handle_duplicate_claim_error
      increment_metric_by_facility_type(
        CheckIn::Constants::CIE_STATSD_BTSSS_DUPLICATE,
        CheckIn::Constants::OH_STATSD_BTSSS_DUPLICATE
      )
    end

    ##
    # Increments the appropriate metric based on facility type
    #
    # @param cie_metric [String] the CIE metric constant
    # @param oh_metric [String] the OH metric constant
    #
    def increment_metric_by_facility_type(cie_metric, oh_metric)
      if @facility_type&.downcase == 'oh'
        StatsD.increment(oh_metric)
      else
        StatsD.increment(cie_metric)
      end
    end
  end
end
