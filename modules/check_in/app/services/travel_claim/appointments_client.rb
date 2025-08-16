# frozen_string_literal: true

require 'securerandom'

module TravelClaim
  class AppointmentsClient < TravelClaim::BaseClient
    ##
    # HTTP POST call to the BTSSS v3 'appointments/find-or-add' endpoint
    # API responds with BTSSS appointments (array)
    #
    # @params:
    #  {
    #   appointmentDateTime: datetime string ('2024-01-01T12:45:34.465Z'),
    #   facilityStationNumber: string (i.e. facilityId),
    #   appointmentName: string, **Required in v3 - min 5, max 100 chars
    #   appointmentType: string, 'CompensationAndPensionExamination' || 'Other'
    #   isComplete: boolean,
    #  }
    #
    # @return [Faraday::Response] with array of appointments in body['data']
    #
    def find_or_add(access_token, params)
      btsss_url = settings.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.info(message: 'Correlation ID', correlation_id:)

      # Transform params to match v3 API expectations
      request_body = build_request_body(params)

      log_to_statsd('appointments', 'find_or_add') do
        connection(server_url: btsss_url).post('api/v3/appointments/find-or-add') do |req|
          req.headers['Authorization'] = "Bearer #{access_token}"
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
          req.body = request_body.to_json
        end
      end
    end

    private

    def build_request_body(params)
      {
        appointmentDateTime: params['appointment_date_time'],
        facilityStationNumber: params['facility_station_number'],
        appointmentName: params['appointment_name'] || 'Medical Appointment',
        appointmentType: params['appointment_type'] || 'Other',
        isComplete: params['is_complete'] || false
      }
    end

    ##
    # Helper function to measure xTIC latency
    # when calling the external Travel Pay API
    def log_to_statsd(service, tag_value)
      start_time = Time.current
      result = yield
      elapsed_time = Time.current - start_time
      StatsD.measure("check_in.travel_claim.#{service}.response_time", elapsed_time,
                     tags: ["travel_claim:#{tag_value}"])
      result
    end
  end
end
