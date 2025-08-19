# frozen_string_literal: true

module TravelClaim
  ##
  # Client for Travel Claim appointment API operations.
  #
  # Handles HTTP communication with appointment endpoints. Inherits from BaseClient
  # for circuit breaker protection and error handling. Expects appointment dates
  # to be provided in ISO 8601 format from the request.
  #
  class AppointmentsClient < BaseClient
    ##
    # Finds or creates an appointment in the Travel Claim system.
    #
    # This method calls the BTSSS API's find-or-create appointment endpoint,
    # which will either return an existing appointment matching the criteria
    # or create a new one. The correlation_id is passed through to maintain
    # request tracing across the entire orchestrator flow.
    #
    # @param tokens [Hash] Authentication tokens hash containing :veis_token and :btsss_token
    # @param appointment_date_time [String] ISO 8601 formatted appointment date/time from request
    # @param facility_id [String] VA facility identifier
    # @param patient_icn [String] Patient's Integrated Control Number
    # @param correlation_id [String] Request correlation ID for tracing
    # @return [Faraday::Response] HTTP response containing appointment data
    # @raise [Common::Exceptions::BackendServiceException] If the API request fails
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
    # @param appointment_date_time [String] ISO 8601 formatted appointment date/time from request
    # @param facility_id [String] VA facility identifier
    # @param patient_icn [String] Patient's Integrated Control Number
    # @return [Hash] Request body hash with camelCase keys as expected by the API
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
    # Combines authentication tokens, correlation ID, and environment-specific
    # subscription keys into the complete headers hash required by the API.
    #
    # @param tokens [Hash] Authentication tokens hash containing :veis_token and :btsss_token
    # @param correlation_id [String] Request correlation ID for tracing
    # @return [Hash] Complete headers hash for the API request
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
