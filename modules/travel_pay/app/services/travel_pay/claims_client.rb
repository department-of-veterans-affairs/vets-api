# frozen_string_literal: true

require 'securerandom'
require_relative './base_client'

module TravelPay
  class ClaimsClient < TravelPay::BaseClient
    ##
    # HTTP GET call to the BTSSS 'claims' endpoint
    # API responds with travel pay claims including status
    #
    # @return [TravelPay::Claim]
    #
    def get_claims(veis_token, btsss_token)
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.debug(message: 'Correlation ID', correlation_id:)

      connection(server_url: btsss_url).get('api/v1/claims') do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['BTSSS-Access-Token'] = btsss_token
        req.headers['X-Correlation-ID'] = correlation_id
        req.headers.merge!(claim_headers)
      end
    end

    ##
    # HTTP POST call to the BTSSS 'claims' endpoint
    # API responds with a new travel pay claim ID
    #
    # @params {
    #  "appointmentId": "string", (BTSSS internal appointment ID - uuid)
    #  "claimName": "string",
    #  "claimantType": "Veteran" (currently, "Veteran" is the only claimant type supported)
    # }
    #
    # @return claimID => string
    #
    def create_claim(veis_token, btsss_token, params = {})
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.debug(message: 'Correlation ID', correlation_id:)

      connection(server_url: btsss_url).post('api/v1.1/claims') do |req|
        req.headers['Authorization'] = "Bearer #{veis_token}"
        req.headers['BTSSS-Access-Token'] = btsss_token
        req.headers['X-Correlation-ID'] = correlation_id
        req.headers.merge!(claim_headers)
        req.body = {
          'appointmentId' => params['btsss_appt_id'],
          'claimName' => params['claim_name'] || 'Travel reimbursement',
          'claimantType' => params['claimant_type'] || 'Veteran'
        }.to_json
      end
    end
  end
end
