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
      Rails.logger.debug(message: 'Correlation ID', correlation_id:)

      query_path = if params.empty?
                     'api/v1.1/appointments'
                   else
                     "api/v1.1/appointments?#{params.to_query}"
                   end

      connection(server_url: btsss_url).get(query_path) do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['BTSSS-Access-Token'] = btsss_token
        req.headers['X-Correlation-ID'] = correlation_id
        req.headers.merge!(claim_headers)
      end
    end
  end
end
