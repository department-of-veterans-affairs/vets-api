# frozen_string_literal: true

require 'securerandom'
require_relative './base_client'

module TravelPay
  class ExpensesClient < TravelPay::BaseClient
    UUID_REGEX = /\A[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[89ABCD][0-9A-F]{3}-[0-9A-F]{12}\z/i

    BASE_PATHS = {
      meal: 'api/v1/expenses/meal',
      mileage: 'api/v2/expenses/mileage',
      parking: 'api/v1/expenses/parking',
      other: 'api/v1/expenses/other'
    }.freeze

    ENDPOINT_MAP = BASE_PATHS.transform_values do |base|
      { add: base, delete: "#{base}/%<expense_id>s" }
    end.freeze

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
      endpoint = expense_endpoint_for_type(expense_type, :add)
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid

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

    ##
    # Generic HTTP DELETE call to the BTSSS 'expenses' endpoints to delete an expense
    # Routes to appropriate endpoint based on expense type
    #
    # @param veis_token [String] VEIS authentication token
    # @param btsss_token [String] BTSSS access token
    # @param expense_type [String] Type of expense ('mileage', 'lodging', 'meal', 'other')
    # @param expense_id [String] UUID of the expense
    # @return [Faraday::Response] API response
    #
    def delete_expense(veis_token, btsss_token, expense_type, expense_id)
      # Validate expense_id
      raise ArgumentError, 'Invalid expense_id' unless expense_id&.match?(UUID_REGEX)

      endpoint_template = expense_endpoint_for_type(expense_type, :delete)
      btsss_url = Settings.travel_pay.base_url
      correlation_id = SecureRandom.uuid
      endpoint = format(endpoint_template, expense_id: expense_id) # rubocop:disable Style/HashSyntax

      Rails.logger.info(message: 'Correlation ID', correlation_id:)
      Rails.logger.info(message: "Deleting #{expense_type} expense to endpoint: #{endpoint}")

      log_to_statsd('expense', "delete_#{expense_type}") do
        connection(server_url: btsss_url).delete(endpoint) do |req|
          req.headers['Authorization'] = "Bearer #{veis_token}"
          req.headers['BTSSS-Access-Token'] = btsss_token
          req.headers['X-Correlation-ID'] = correlation_id
          req.headers.merge!(claim_headers)
        end
      end
    end

    private

    def expense_endpoint_for_type(expense_type, action = :add)
      endpoint_data = ENDPOINT_MAP[expense_type.to_sym]
      raise ArgumentError, "Unsupported expense_type: #{expense_type}" unless endpoint_data

      endpoint_data[action]
    end
  end
end
