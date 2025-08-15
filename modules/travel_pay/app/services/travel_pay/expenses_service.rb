# frozen_string_literal: true

require 'securerandom'

module TravelPay
  class ExpensesService
    def initialize(auth_manager)
      @auth_manager = auth_manager
    end

    # Old method to handle SMOC expense creation
    # TODO: Handle SMOC expenses in create_expense and remove add_expense
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

      # Route to appropriate expense creation method based on type
      case params['expense_type']
      when 'mileage'
        # For mileage expenses, use the existing add_expense method for SMOC compatibility
        # Convert purchase_date to appt_date format expected by add_expense
        mileage_params = {
          'claim_id' => params['claim_id'],
          'appt_date' => params['purchase_date'] || params['appt_date'],
          'description' => params['description'] || 'mileage',
          'trip_type' => params['trip_type'] || 'RoundTrip'
        }
        add_expense(mileage_params)
      else
        # For other expense types, use the generic client method
        create_general_expense(veis_token, btsss_token, params)
      end
    end

    private

    def create_general_expense(veis_token, btsss_token, params)
      # Use the new generic add_expense method from the client
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

    ##
    # Builds the request body for the expense API call
    #
    # @param params [Hash] The expense parameters
    # @return [Hash] The formatted request body
    #
    def build_expense_request_body(params)
      {
        'claimId' => params['claim_id'],
        'dateIncurred' => params['purchase_date'],
        'description' => params['description'],
        'amount' => params['cost_requested'],
        'expenseType' => params['expense_type']
      }
    end

    def client
      TravelPay::ExpensesClient.new
    end
  end
end
