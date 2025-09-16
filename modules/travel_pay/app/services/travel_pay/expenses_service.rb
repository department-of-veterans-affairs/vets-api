# frozen_string_literal: true

require 'securerandom'
require 'base64'

module TravelPay
  class ExpensesService
    def initialize(auth_manager)
      @auth_manager = auth_manager
    end

    # Method to add a mileage expense, specifically for SMOC
    # TODO: Integrate into create_expense when ready to handle non-SMOC mileage expenses
    def add_expense(params = {})
      @auth_manager.authorize => { veis_token:, btsss_token: }

      # check for required params (that don't have a default set in the client)
      unless params['claim_id'] && params['appt_date']
        raise ArgumentError,
              message: 'You must provide a claim ID and appointment date to add an expense.'
      end
      new_expense_response = client.add_mileage_expense(veis_token, btsss_token, params)

      new_expense_response.body['data']
    end

    # Method to handle expense creation via the API
    def create_expense(params = {})
      @auth_manager.authorize => { veis_token:, btsss_token: }

      # Validate required params
      raise ArgumentError, 'You must provide a claim ID to create an expense.' unless params['claim_id']

      Rails.logger.info("Creating general expense of type: #{params['expense_type']}")

      # Build the request body for the API
      request_body = build_expense_request_body(params)

      begin
        response = client.add_expense(veis_token, btsss_token, params['expense_type'], request_body)
        response.body['data']
      rescue Faraday::Error => e
        Rails.logger.error("Failed to create expense via API: #{e.message}")
        raise TravelPay::ServiceError.raise_mapped_error(e)
      end
    end

    private

    ##
    # Builds the request body for the expense API call
    #
    # @param params [Hash] The expense parameters
    # @return [Hash] The formatted request body
    #
    def build_expense_request_body(params)
      request_body = {
        'claimId' => params['claim_id'],
        'dateIncurred' => params['purchase_date'],
        'description' => params['description'],
        'costRequested' => params['cost_requested'],
        'expenseType' => params['expense_type']
      }

      # Include placeholder receipt unless feature flag is enabled to exclude it
      unless Flipper.enabled?(:travel_pay_exclude_expense_placeholder_receipt)
        request_body['expenseReceipt'] = build_placeholder_receipt
      end

      request_body
    end

    ##
    # Builds the smallest possible placeholder receipt that satisfies the client contract
    #
    # @return [Hash] The minimal placeholder receipt data
    #
    def build_placeholder_receipt
      placeholder_data = 'placeholder'
      {
        'contentType' => 'text/plain',
        'length' => placeholder_data.length,
        'fileName' => 'placeholder.txt',
        'fileData' => Base64.strict_encode64(placeholder_data)
      }
    end

    def client
      TravelPay::ExpensesClient.new
    end
  end
end
