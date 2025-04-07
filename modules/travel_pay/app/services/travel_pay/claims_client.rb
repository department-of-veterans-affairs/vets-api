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
      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      log_to_statsd('claims', 'get_all') do
        connection(server_url: btsss_url).get('api/v1.2/claims') do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
        end
      end
    end

    ##
    # HTTP GET call to the BTSSS 'claims/:id' endpoint
    # API responds with travel pay claim details including additional fields:
    #   rejectionReason - The most recent rejection code and description
    #   totalCostRequested
    #   reimbursementAmount
    #   facilityName
    #
    # @return [TravelPay::ClaimDetails]
    #
    def get_claim_by_id(veis_token, btsss_token, claim_id)
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      log_to_statsd('claims', 'get_by_id') do
        connection(server_url: btsss_url).get("api/v1.2/claims/#{claim_id}") do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
        end
      end
    end

    ##
    # HTTP GET call to the BTSSS 'claims/search-by-appointment-date' endpoint
    # API responds with travel pay claims including status for the specified date-range
    #
    # @params {
    # startDate: string ('2024-01-01T12:45:34Z') (Required)
    # endDate: string ('2024-01-01T12:45:34Z') (Required)
    # pageNumber: int
    # pageSize: int
    # sortField: string
    # sortDirection: string
    # }
    # @return [TravelPay::Claim]
    #
    def get_claims_by_date(veis_token, btsss_token, params = {})
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.info(message: 'Correlation ID', correlation_id:)

      url_params = params.transform_keys { |k| k.to_s.camelize(:lower) }
      log_to_statsd('claims', 'get_by_date') do
        connection(server_url: btsss_url)
          # URL subject to change once v1.2 is available (proposed endpoint: '/search')
          .get("api/v1.2/claims/search-by-appointment-date?#{url_params.to_query}") do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
        end
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
      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      log_to_statsd('claims', 'create') do
        connection(server_url: btsss_url).post('api/v1.2/claims') do |req|
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

    ##
    # HTTP POST call to the BTSSS 'claims/:id/submit' endpoint
    # API responds with confirmation of claim submission
    #
    # @params {
    #  "claimId": "string",
    # }
    #
    # @return Faraday::Response claim submission payload
    #
    def submit_claim(veis_token, btsss_token, claim_id)
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      log_to_statsd('claims', 'submit') do
        connection(server_url: btsss_url).patch("api/v1.2/claims/#{claim_id}/submit") do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
        end
      end
    end
  end
end
