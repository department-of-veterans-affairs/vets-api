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
    # @return [Hash] success response with claim ID
    # @raise [Common::Exceptions::BackendServiceException] for API failures
    # @raise [ArgumentError] for validation failures
    #
    def submit_claim
      validate_parameters
      process_claim_submission
    rescue Common::Exceptions::BackendServiceException => e
      raise e
    rescue => e
      log_message(:error, 'Unexpected error', error_class: e.class.name)
      raise_backend_service_exception('An unexpected error occurred')
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
      submit_claim_for_processing(claim_id)

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

      response = client.send_mileage_expense_request(claim_id:, date_incurred: @appointment_date)

      raise_backend_service_exception('Failed to add expense', response.status) unless response.status == 200
    end

    ##
    # Submits the claim for final processing.
    #
    # @param claim_id [String] the claim ID
    # @raise [Common::Exceptions::BackendServiceException] if submission fails
    #
    def submit_claim_for_processing(claim_id)
      log_message(:info, 'Submit claim', uuid: @uuid)

      response = client.send_claim_submission_request(claim_id:)

      raise_backend_service_exception('Failed to submit claim', response.status) unless response.status == 200
    end

    ##
    # Returns a configured TravelPayClient instance.
    #
    # @return [TravelClaim::TravelPayClient] configured client
    #
    def client
      @client ||= TravelClaim::TravelPayClient.new(
        uuid: @uuid,
        appointment_date_time: @appointment_date,
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
  end
end
