# frozen_string_literal: true

require 'securerandom'
require_relative './base_client'

module TravelPay
  class AppointmentsClient < TravelPay::BaseClient
    ##
    # HTTP GET call to the BTSSS 'appointments' endpoint
    # API responds with BTSSS appointments
    #
    # Available @params: (for Travel Pay API)
    #   excludeWithClaims: boolean
    #   pageNumber: int
    #   pageSize: int
    #   sortField: string
    #   sortDirection: string (None, Ascending, Descending)
    #
    # @return [TravelPay::Appointment]
    #
    def get_all_appointments(veis_token, btsss_token, params = {})
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      query_path = if params.empty?
                     'api/v2/appointments'
                   else
                     "api/v2/appointments?#{params.to_query}"
                   end
      log_to_statsd('appointments', 'get_all') do
        connection(server_url: btsss_url).get(query_path) do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
        end
      end
    end

    ##
    # HTTP POST call to the BTSSS 'appointments/find-or-create' endpoint
    # API responds with BTSSS appointment ID
    #
    # @params:
    #  {
    #   appointmentDateTime: datetime string (ex: '2024-01-01T12:45:34.465Z'),
    #   facilityStationNumber: string (ex: '983'),
    #   appointmentType: string, (ex:'CompensationAndPensionExamination' || 'Other')
    #   isComplete: boolean, (ex: true)
    #  }
    # @param use_v4_api: boolean - if true, uses v4 API endpoint, otherwise uses v2
    #
    # @return [TravelPay::Appointment]
    #
    def find_or_create(veis_token, btsss_token, params, use_v4_api: false)
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      url_params = params.transform_keys { |k| k.to_s.camelize(:lower) }

      # Choose API version based on feature flag
      api_version = use_v4_api ? 'v4' : 'v2'
      endpoint = "api/#{api_version}/appointments/find-or-add"

      log_to_statsd('appointments', 'find_or_create') do
        connection(server_url: btsss_url).post(endpoint) do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
          req.body = url_params.to_json
        end
      end
    end
  end
end
