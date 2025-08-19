# frozen_string_literal: true

module TravelClaim
  ##
  # Client for Travel Claim appointment API operations.
  #
  class AppointmentsClient < BaseClient
    ##
    # Finds or creates an appointment in the Travel Claim system.
    #
    # @param tokens [Hash] Authentication tokens hash
    # @param appointment_date_time [String] ISO 8601 formatted appointment date/time
    # @param facility_id [String] VA facility identifier
    # @param patient_icn [String] Patient's ICN
    # @param correlation_id [String] Request correlation ID
    # @return [Faraday::Response] HTTP response containing appointment data
    #
    def find_or_create_appointment(tokens:, appointment_date_time:, facility_id:, patient_icn:, correlation_id:)
      body = build_appointment_body(appointment_date_time:, facility_id:, patient_icn:)
      headers = build_appointment_headers(tokens, correlation_id)

      full_url = "#{settings.claims_url_v2}/api/v3/appointments/find-or-create"
      perform(:post, full_url, body, headers)
    end

    private

    ##
    # Builds the request body for the appointment API call.
    #
    # @param appointment_date_time [String] ISO 8601 formatted appointment date/time
    # @param facility_id [String] VA facility identifier
    # @param patient_icn [String] Patient's ICN
    # @return [Hash] Request body hash
    #
    def build_appointment_body(appointment_date_time:, facility_id:, patient_icn:)
      {
        appointmentDateTime: appointment_date_time,
        facilityId: facility_id,
        patientIcn: patient_icn
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
