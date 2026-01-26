# frozen_string_literal: true

module TravelClaim
  ##
  # Client for Travel Claim appointment API operations.
  #
  class AppointmentsClient < BaseClient
    ##
    # Finds or adds an appointment in the Travel Claim system.
    #
    # @param tokens [Hash] Authentication tokens hash
    # @param appointment_date_time [String] ISO 8601 formatted appointment date/time
    # @param facility_id [String] VA facility identifier (maps to facilityStationNumber)
    # @param correlation_id [String] Request correlation ID
    # @return [Faraday::Response] HTTP response containing appointment data
    #
    def find_or_create_appointment(tokens:, appointment_date_time:, facility_id:, correlation_id:)
      body = build_appointment_body(appointment_date_time:, facility_id:)
      headers = build_appointment_headers(tokens, correlation_id)

      full_url = "#{settings.claims_base_path}/api/v3/appointments/find-or-add"
      perform(:post, full_url, body, headers)
    end

    private

    ##
    # Builds the request body for the appointment API call.
    #
    # @param appointment_date_time [String] ISO 8601 formatted appointment date/time
    # @param facility_id [String] VA facility identifier
    # @return [Hash] Request body hash
    #
    def build_appointment_body(appointment_date_time:, facility_id:)
      {
        appointmentDateTime: appointment_date_time,
        facilityStationNumber: facility_id
      }
    end

    ##
    # Builds the request headers for the appointment API call.
    #
    # @param tokens [Hash] Authentication tokens hash
    # @param correlation_id [String] Request correlation ID
    # @return [Hash] Headers hash
    #
    def build_appointment_headers(tokens, correlation_id)
      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{tokens[:veis_token]}",
        'X-BTSSS-Token' => tokens[:btsss_token],
        'X-Correlation-ID' => correlation_id
      }

      headers.merge!(claim_headers)
      headers
    end
  end
end
