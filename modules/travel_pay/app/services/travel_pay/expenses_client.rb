# frozen_string_literal: true

require 'securerandom'
require_relative './base_client'

module TravelPay
  class ExpensesClient < TravelPay::BaseClient
    ##
    # Generic HTTP POST call to the BTSSS 'expenses' endpoints to add a new expense
    # Routes to appropriate endpoint based on expense type
    #
    # @param veis_token [String] VEIS authentication token
    # @param btsss_token [String] BTSSS access token
    # @param expense_type [String] Type of expense ('mileage', 'lodging', 'meal', 'other')
    # @param body [Hash] Request body to send to the API
    #
    # @return [Faraday::Response] API response
    #
    def add_expense(veis_token, btsss_token, expense_type, body = {})
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      endpoint = expense_endpoint_for_type(expense_type)

      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      Rails.logger.info(message: "Adding #{expense_type} expense to endpoint: #{endpoint}")

      log_to_statsd('expense', "add_#{expense_type}") do
        connection(server_url: btsss_url).post(endpoint) do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
          req.body = body.to_json
        end
      end
    end

    ##
    # Generic HTTP GET call to the BTSSS 'expenses' endpoints to retrieve an expense by ID
    # Routes to appropriate endpoint based on expense type
    #
    # @param veis_token [String] VEIS authentication token
    # @param btsss_token [String] BTSSS access token
    # @param expense_type [String] Type of expense ('other')
    # @param expense_id [String] UUID of the expense to retrieve
    #
    # @return [Faraday::Response] API response with expense details
    #
    def get_expense(veis_token, btsss_token, expense_type, expense_id)
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      endpoint = "#{expense_endpoint_for_type(expense_type)}/#{expense_id}"

      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      Rails.logger.info(message: "Getting #{expense_type} expense from endpoint: #{endpoint}")

      log_to_statsd('expense', "get_#{expense_type}") do
        connection(server_url: btsss_url).get(endpoint) do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
        end
      end
    end

    ##
    # HTTP POST call to the BTSSS 'expenses' endpoint to add a new mileage expense
    # API responds with an expenseId
    #
    # @external API params {
    #   "claimId": "string", // uuid of the claim to attach the expense to
    #   "dateIncurred": "2024-10-02T14:36:38.043Z", // This is the appointment date-time
    #   "description": "string", // ?? Not sure what this is or if it is required
    #   "tripType": "string" // Enum: [ OneWay, RoundTrip, Unspecified ]
    # }
    #
    # @params {
    #   'claim_id' => 'string'
    #   'appt_date' => 'string'
    #   'trip_type' => 'OneWay' | 'RoundTrip' | 'Unspecified'
    #   'description' => 'string'
    # }
    #
    # @return expenseId => string
    #
    def add_mileage_expense(veis_token, btsss_token, params = {})
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      log_to_statsd('expense', 'add_mileage') do
        connection(server_url: btsss_url).post('api/v2/expenses/mileage') do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
          req.body = {
            'claimId' => params['claim_id'],
            'dateIncurred' => params['appt_date'],
            'tripType' => params['trip_type'] || 'RoundTrip', # default to Round Trip if not specified
            'description' => params['description'] || 'mileage' # this is required, default to mileage
          }.to_json
        end
      end
    end

    private

    ##
    # Returns the appropriate API endpoint for the given expense type
    #
    # @param expense_type [String] The type of expense
    # @return [String] The API endpoint path
    #
    def expense_endpoint_for_type(expense_type)
      case expense_type
      when 'other'
        'api/v1/expenses/other'
      else
        raise ArgumentError, "Unsupported expense type: #{expense_type}. Only 'other' is currently supported."
      end
    end
  end
end
