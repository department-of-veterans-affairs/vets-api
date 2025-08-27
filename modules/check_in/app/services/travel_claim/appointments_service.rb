# frozen_string_literal: true

module TravelClaim
  # Service for managing Travel Claim appointment operations.
  #
  # This class is responsible for finding or creating appointments in the Travel Claim system.
  # It uses an authentication manager to obtain tokens and interacts with the Travel Claim API.
  #
  # == Usage Example
  #   auth_manager = TravelClaim::AuthManager.new(...)
  #   session = CheckIn::V2::Session.new(...)
  #   service = TravelClaim::AppointmentsService.new(
  #     check_in_session: session,
  #     auth_manager: auth_manager
  #   )
  #   result = service.find_or_create_appointment(
  #     appointment_date_time: "2024-06-01T10:00:00Z",
  #     facility_id: "123",
  #     correlation_id: "abc-123"
  #   )
  #
  # == Initialization Parameters
  # @param check_in_session [CheckIn::V2::Session] The check-in session associated with the appointment.
  # @param auth_manager [TravelClaim::AuthManager] The authentication manager used to obtain tokens.
  #
  class AppointmentsService
    attr_reader :auth_manager, :check_in_session

    ##
    # @param check_in_session [CheckIn::V2::Session] Check-in session
    # @param auth_manager [TravelClaim::AuthManager] Authentication manager
    #
    def initialize(check_in_session:, auth_manager:)
      @check_in_session = check_in_session
      @auth_manager = auth_manager
      @client = AppointmentsClient.new
    end

    ##
    # Finds or adds an appointment in the Travel Claim system.
    # Gets authentication tokens from the AuthManager and calls the Travel Claim API.
    #
    # @param appointment_date_time [String] ISO 8601 formatted appointment date/time
    # @param facility_id [String] VA facility identifier
    # @param correlation_id [String] Request correlation ID for tracing
    # @return [Hash] Hash containing appointment data: { data: Hash }
    #
    def find_or_create_appointment(appointment_date_time:, facility_id:, correlation_id:)
      validate_appointment_date_time(appointment_date_time)

      tokens = auth_manager.authorize
      faraday_response = make_appointment_request(tokens, appointment_date_time, facility_id, correlation_id)
      appointments = faraday_response.body['data']

      {
        # this returns an array of matching appointments - just return the first one
        data: appointments&.first
      }
    rescue => e
      error_class = e.class.name
      Rails.logger.error('Travel Claim API error',
                         { uuid: check_in_session&.uuid, error_class:, error_message: e.message })
      raise e
    end

    private

    def validate_appointment_date_time(appointment_date_time)
      if appointment_date_time.nil?
        raise ArgumentError, 'Invalid appointment date provided (appointment date cannot be nil).'
      elsif !valid_iso_format?(appointment_date_time)
        raise ArgumentError, 'Invalid appointment date format. Expected ISO 8601 format.'
      end
    end

    def valid_iso_format?(date_string)
      return false unless date_string.is_a?(String)

      begin
        DateTime.iso8601(date_string)
        true
      rescue ArgumentError
        false
      end
    end

    def make_appointment_request(tokens, appointment_date_time, facility_id, correlation_id)
      @client.find_or_create_appointment(
        tokens:,
        appointment_date_time:,
        facility_id:,
        correlation_id:
      )
    end
  end
end
