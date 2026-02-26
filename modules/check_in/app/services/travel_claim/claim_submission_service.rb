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
    VALIDATION_ERROR = 'validation_error'
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
      },
      VALIDATION_ERROR => {
        cie: CheckIn::Constants::CIE_STATSD_VALIDATION_ERROR,
        oh: CheckIn::Constants::OH_STATSD_VALIDATION_ERROR
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
    # @raise [Common::Exceptions::BackendServiceException] for API or validation failures
    #
    def submit_claim
      validate_parameters
      result = process_claim_submission

      send_notification_if_enabled if result['success']

      result
    rescue Common::Exceptions::BackendServiceException => e
      log_submission_failure(error: e)
      increment_failure_metric
      handle_duplicate_claim_error if @current_step && duplicate_claim_error?(e)
      send_error_notification_if_enabled(e)
      raise e
    rescue => e
      log_submission_failure(error: e)
      increment_failure_metric
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
      raise_validation_error('Appointment date is required', 'VA902') if @appointment_date.blank?
      raise_validation_error('Facility type is required', 'VA903') if @facility_type.blank?
      raise_validation_error('Check-in UUID is required', 'VA904') if @check_in_uuid.blank?

      normalized_appointment_datetime
      appointment_date_yyyy_mm_dd
    end

    def normalized_time_utc
      @normalized_time_utc ||= begin
        s = @appointment_date

        unless s.is_a?(String) && s.include?('T')
          raise_validation_error(
            'Appointment date must include a time component (e.g., 2025-09-16T10:00:00Z)',
            'VA905'
          )
        end

        t = Time.iso8601(s)
        Time.utc(t.year, t.month, t.day, t.hour, t.min, t.sec)
      rescue ArgumentError
        raise_validation_error(
          'Appointment date must be a valid ISO 8601 date-time (e.g., 2025-09-16T10:00:00Z)',
          'VA905'
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
      response = auth_manager.with_auth do
        client.send_appointment_request(
          veis_token: auth_manager.veis_token,
          btsss_token: auth_manager.btsss_token
        )
      end
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
      response = auth_manager.with_auth do
        client.send_claim_request(
          veis_token: auth_manager.veis_token,
          btsss_token: auth_manager.btsss_token,
          appointment_id:
        )
      end
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
      response = auth_manager.with_auth do
        client.send_mileage_expense_request(
          veis_token: auth_manager.veis_token,
          btsss_token: auth_manager.btsss_token,
          claim_id:,
          date_incurred: appointment_date_yyyy_mm_dd
        )
      end

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
      response = auth_manager.with_auth do
        client.send_claim_submission_request(
          veis_token: auth_manager.veis_token,
          btsss_token: auth_manager.btsss_token,
          claim_id:
        )
      end

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
        appointment_date_time: normalized_appointment_datetime,
        station_number:,
        check_in_uuid: @check_in_uuid,
        facility_type: @facility_type,
        correlation_id:
      )
    end

    ##
    # Returns a configured AuthManager instance.
    #
    # @return [TravelClaim::AuthManager] configured auth manager
    #
    def auth_manager
      @auth_manager ||= TravelClaim::AuthManager.new(
        icn:,
        station_number:,
        facility_type: @facility_type,
        correlation_id:
      )
    end

    ##
    # Generates or returns the correlation ID for request tracing.
    #
    # @return [String] correlation ID
    #
    def correlation_id
      @correlation_id ||= SecureRandom.uuid
    end

    ##
    # Returns the Redis client for fetching patient data.
    #
    # @return [TravelClaim::RedisClient] Redis client instance
    #
    def redis_client
      @redis_client ||= TravelClaim::RedisClient.build
    end

    ##
    # Retrieves the patient ICN from Redis.
    #
    # @return [String] patient ICN
    # @raise [Common::Exceptions::BackendServiceException] if ICN not found
    #
    def icn
      @icn ||= begin
        value = redis_client.icn(uuid: @check_in_uuid)
        raise_backend_service_exception('Patient ICN not found in session', 400, 'VA906') if value.blank?

        value
      end
    end

    ##
    # Retrieves the station number from Redis.
    #
    # @return [String] facility station number
    # @raise [Common::Exceptions::BackendServiceException] if station number not found
    #
    def station_number
      @station_number ||= begin
        value = redis_client.station_number(uuid: @check_in_uuid)
        raise_backend_service_exception('Station number not found in session', 400, 'VA907') if value.blank?

        value
      end
    end

    ##
    # Logs failure of travel claim submission with step context and error details.
    #
    # @param error [Exception] the error that caused the failure
    #
    def log_submission_failure(error:)
      return unless Flipper.enabled?(:check_in_experience_travel_claim_logging)

      log_data = {
        message: "#{CheckIn::Constants::LOG_PREFIX}: Submission FAILURE",
        facility_type: @facility_type,
        check_in_uuid: @check_in_uuid,
        correlation_id:,
        failed_step: @current_step || 'unknown',
        error_class: error.class.name
      }

      log_data[:http_status] = error.original_status if error.respond_to?(:original_status)

      if error.respond_to?(:response_values) && error.response_values[:detail].present?
        log_data[:error_detail] = Logging::Helper::DataScrubber.scrub(error.response_values[:detail])
      end

      Rails.logger.error(log_data)
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

    def raise_validation_error(detail, code)
      increment_error_metric(VALIDATION_ERROR)
      raise_backend_service_exception(detail, 400, code)
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
        Rails.logger.error("#{CheckIn::Constants::LOG_PREFIX}: Failed to extract claim number",
                           error: e.message)
      end
      'unknown'
    end

    ##
    # Sends a success notification if feature flag is enabled
    #
    def send_notification_if_enabled
      return unless Flipper.enabled?(:check_in_experience_travel_reimbursement)
      return if @check_in_uuid.blank?

      template_id = success_template_id
      claim_number_last_four = @claim_number_last_four

      log_notification('success', template_id:, claim_last_four: claim_number_last_four)

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
      return unless Flipper.enabled?(:check_in_experience_travel_reimbursement)
      return if @check_in_uuid.blank?

      increment_metric_by_facility_type(
        CheckIn::Constants::CIE_STATSD_ERROR_NOTIFICATION,
        CheckIn::Constants::OH_STATSD_ERROR_NOTIFICATION
      )

      template_id = determine_error_template_id(error)
      claim_number_last_four = @claim_number_last_four || 'unknown'

      log_notification('error', template_id:, failed_step: @current_step || 'unknown',
                                error_class: error.class.name)

      CheckIn::TravelClaimNotificationJob.perform_async(
        @check_in_uuid,
        @appointment_date_yyyy_mm_dd,
        template_id,
        claim_number_last_four
      )
    end

    def log_notification(type, **extra)
      return unless Flipper.enabled?(:check_in_experience_travel_claim_logging)

      log_data = {
        message: "#{CheckIn::Constants::LOG_PREFIX}: Sending #{type} notification",
        check_in_uuid: @check_in_uuid,
        facility_type: @facility_type,
        correlation_id:
      }.merge(extra)

      Rails.logger.info(log_data)
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
      if error.is_a?(Common::Exceptions::BackendServiceException) && duplicate_claim_error?(error)
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
