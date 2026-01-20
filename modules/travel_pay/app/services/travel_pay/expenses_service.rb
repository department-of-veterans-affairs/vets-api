# frozen_string_literal: true

require 'securerandom'
require 'base64'

module TravelPay
  class ExpensesService
    include ExpenseNormalizer

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

      Rails.logger.info("Creating expense of type: #{params['expense_type']}")
      # Build the request body for the API
      request_body = build_expense_request_body(params)

      response = client.add_expense(veis_token, btsss_token, params['expense_type'], request_body)
      response.body['data']
    rescue Faraday::Error => e
      Rails.logger.error("Failed to create expense via API: #{e.message}")
      TravelPay::ServiceError.raise_mapped_error(e)
    end

    # Method to retrieve an expense by ID via the API
    def get_expense(expense_type, expense_id)
      @auth_manager.authorize => { veis_token:, btsss_token: }

      # Validate required params
      raise ArgumentError, 'You must provide an expense type to get an expense.' if expense_type.blank?
      raise ArgumentError, 'You must provide an expense ID to get an expense.' if expense_id.blank?

      Rails.logger.info("Getting expense of type: #{expense_type} with ID: #{expense_id}")

      response = client.get_expense(veis_token, btsss_token, expense_type, expense_id)
      expense = response.body['data']

      # Normalize expense type
      normalize_expense(expense)
    rescue Faraday::Error => e
      Rails.logger.error("Failed to get expense via API: #{e.message}")
      TravelPay::ServiceError.raise_mapped_error(e)
    end

    # Method to handle expense update via the API
    def update_expense(expense_id, expense_type, params = {})
      raise ArgumentError, 'You must provide an expense ID to create an expense.' if expense_id.blank?
      raise ArgumentError, 'You must provide an expense type to create an expense.' if expense_type.blank?
      raise ArgumentError, 'You must provide at least one field to update an expense.' if params.blank?

      @auth_manager.authorize => { veis_token:, btsss_token: }
      Rails.logger.info("Updating expense of type: #{expense_type}")

      # Build the request body for the API
      request_body = build_expense_request_body(params)

      response = client.update_expense(veis_token, btsss_token, expense_id, expense_type, request_body)
      response.body['data']
    end

    # Method to handle expense deletion via the API
    def delete_expense(expense_id:, expense_type:)
      raise ArgumentError, 'You must provide an expense ID to create an expense.' if expense_id.blank?
      raise ArgumentError, 'You must provide an expense type to create an expense.' if expense_type.blank?

      @auth_manager.authorize => { veis_token:, btsss_token: }
      Rails.logger.info("Deleting expense of type: #{expense_type}")

      response = client.delete_expense(veis_token, btsss_token, expense_id, expense_type)
      response.body['data']
    end

    private

    ##
    # Builds the request body for the expense API call
    # Transforms snake_case params to camelCase for the API
    #
    # @param params [Hash] The expense parameters
    # @return [Hash] The formatted request body
    #
    def build_expense_request_body(params)
      # Map of special cases where the API field name doesn't follow simple camelCase conversion
      special_mappings = {
        'purchase_date' => 'dateIncurred',
        'receipt' => 'expenseReceipt'
      }

      request_body = {}

      params.each do |key, value|
        next if value.nil?

        # Use special mapping if it exists, otherwise convert to camelCase
        key_str = key.to_s
        api_key = special_mappings[key_str] || key_str.camelize(:lower)

        # Transform hashes (like receipt)
        request_body[api_key] = camelize_hash_keys(value)
      end

      request_body
    end

    ##
    # Transforms hash values to camelCase
    # For receipt parameter which is a hash with properties
    #
    # @param value [Object] The value to transform
    # @return [Object] The transformed value
    #
    def camelize_hash_keys(value)
      case value
      when Hash
        value.transform_keys { |k| k.to_s.camelize(:lower) }
      else
        value
      end
    end

    def client
      TravelPay::ExpensesClient.new
    end
  end
end
