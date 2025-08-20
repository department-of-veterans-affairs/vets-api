# frozen_string_literal: true

module TravelClaim
  ##
  # Service for Travel Claim appointment operations.
  # Gets authentication tokens from the provided AuthManager.
  #
  class AppointmentsService

    #   @return [CheckIn::V2::Session, nil] Check-in session
    attr_reader :auth_manager, :check_in_session

    ##
    # @param opts [Hash] Options hash
    # @option opts [CheckIn::V2::Session] :check_in_session Check-in session
    # @option opts [CheckIn::V2::Session] :check_in Alias for :check_in_session
    # @option opts [TravelClaim::AuthManager] :auth_manager Authentication manager
    #
    def initialize(opts = {})
      @check_in_session = opts[:check_in_session] || opts[:check_in]
      @auth_manager = opts[:auth_manager]
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
        Rails.logger.error('Invalid appointment date provided (appointment date cannot be nil).')
        raise ArgumentError, 'Invalid appointment date provided (appointment date cannot be nil).'
      elsif !valid_iso_format?(appointment_date_time)
        Rails.logger.error('Invalid appointment date format. Expected ISO 8601 format.')
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
