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

    ##
    # Submits a travel claim using the V3 API.
    #
    # @param claim_id [String] The claim ID to submit
    # @param correlation_id [String] Request correlation ID
    # @return [Faraday::Response] HTTP response from the submit operation
    #
    def submit_claim_v3(claim_id:, correlation_id:)
      headers = build_submit_headers(correlation_id)
      full_url = "#{settings.claims_url_v2}/api/v3/claims/#{claim_id}/submit"

      patch(full_url, nil, headers)
    end

    ##
    # Performs HTTP PATCH requests.
    # Required for V3 API endpoints that use PATCH method.
    #
    # @param path [String] Full URL or path for the request
    # @param params [Hash, String] Request body or query parameters
    # @param headers [Hash] Additional request headers
    # @param options [Hash] Additional options for the request
    # @return [Faraday::Response] The HTTP response object
    #
    def patch(path, params, headers = nil, options = nil)
      request(:patch, path, params, headers, options || {})
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

    ##
    # Builds the request headers for the submit claim V3 API call.
    #
    # @param correlation_id [String] Request correlation ID
    # @return [Hash] Headers hash
    #
    def build_submit_headers(correlation_id)
      headers = {
        'Accept' => 'application/json',
        'X-Correlation-ID' => correlation_id
      }

      headers.merge!(claim_headers)
      headers
    end
  end
end
