# frozen_string_literal: true

require 'securerandom'
require_relative './base_client'

module TravelPay
  class ClaimsClient < TravelPay::BaseClient
    def initialize(version_map = nil)
      super()
      @version_map = version_map
    end

    ##
    # HTTP GET call to the BTSSS 'claims' endpoint
    # API responds with travel pay claims including status
    #
    # @return [TravelPay::Claim]
    #
    def get_claims(veis_token, btsss_token, params = {})
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      url_params = params.transform_keys { |k| k.to_s.camelize(:lower) }

      has_version_override = @version_map || @version_map.key?(__method__)
      version = has_version_override ? @version_map[__method__] : 'v2'

      log_to_statsd('claims', 'get_all') do
        connection(server_url: btsss_url).get("api/#{version}/claims", url_params) do |req|
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

      has_version_override = @version_map || @version_map.key?(__method__)
      version = has_version_override ? @version_map[__method__] : 'v2'

      log_to_statsd('claims', 'get_by_id') do
        connection(server_url: btsss_url).get("api/#{version}/claims/#{claim_id}") do |req|
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

      has_version_override = @version_map || @version_map.key?(__method__)
      version = has_version_override ? @version_map[__method__] : 'v2'

      log_to_statsd('claims', 'get_by_date') do
        connection(server_url: btsss_url)
          .get("api/#{version}/claims/search-by-appointment-date", url_params) do |req|
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

      has_version_override = @version_map || @version_map.key?(__method__)
      version = has_version_override ? @version_map[__method__] : 'v2'

      log_to_statsd('claims', 'create') do
        connection(server_url: btsss_url).post("api/#{version}/claims") do |req|
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
    # HTTP PATCH call to the BTSSS 'claims/:id/submit' endpoint
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

      has_version_override = @version_map || @version_map.key?(__method__)
      version = has_version_override ? @version_map[__method__] : 'v2'

      log_to_statsd('claims', 'submit') do
        connection(server_url: btsss_url).patch("api/#{version}/claims/#{claim_id}/submit") do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
        end
      end
    end
  end
end
