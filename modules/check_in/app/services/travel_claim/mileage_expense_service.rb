# frozen_string_literal: true

module TravelClaim
  # Service for managing Travel Claim mileage expense operations.
  #
  # This class is responsible for adding mileage expenses to travel claims in the Travel Claim system.
  # It uses an authentication manager to obtain tokens and interacts with the Travel Claim API.
  #
  # == Usage Example
  #   auth_manager = TravelClaim::AuthManager.new(...)
  #   session = CheckIn::V2::Session.new(...)
  #   service = TravelClaim::MileageExpenseService.new(
  #     check_in_session: session,
  #     auth_manager: auth_manager
  #   )
  #   result = service.add_mileage_expense(
  #     claim_id: "claim-uuid-123",
  #     date_incurred: "2024-06-01T10:00:00Z",
  #     correlation_id: "abc-123"
  #   )
  #
  # == Initialization Parameters
  # @param check_in_session [CheckIn::V2::Session] The check-in session associated with the mileage expense.
  # @param auth_manager [TravelClaim::AuthManager] The authentication manager used to obtain tokens.
  #
  class MileageExpenseService
    attr_reader :auth_manager, :check_in_session

    ##
    # @param check_in_session [CheckIn::V2::Session] Check-in session
    # @param auth_manager [TravelClaim::AuthManager] Authentication manager
    #
    def initialize(check_in_session:, auth_manager:)
      @check_in_session = check_in_session
      @auth_manager = auth_manager
      @client = MileageExpenseClient.new
    end

    ##
    # Adds a mileage expense to an existing travel claim.
    # Gets authentication tokens from the AuthManager and calls the Travel Claim API.
    #
    # @param claim_id [String] UUID of the travel claim to add the expense to
    # @param date_incurred [String] ISO 8601 formatted date when the expense was incurred
    # @param correlation_id [String] Request correlation ID for tracing
    # @return [Hash] Hash containing expense data: { data: Hash }
    #
    def add_mileage_expense(claim_id:, date_incurred:, correlation_id:)
      validate_mileage_expense_parameters(claim_id, date_incurred)

      tokens = auth_manager.authorize
      faraday_response = make_mileage_expense_request(
        tokens, claim_id, date_incurred, correlation_id
      )
      expense_data = faraday_response.body['data']

      {
        data: expense_data
      }
    rescue => e
      error_class = e.class.name
      Rails.logger.error('Travel Claim Mileage Expense API error',
                         { uuid: check_in_session&.uuid, error_class: })
      raise e
    end

    private

    def validate_mileage_expense_parameters(claim_id, date_incurred)
      raise ArgumentError, 'Invalid claim ID provided (claim ID cannot be nil).' if claim_id.nil?

      if date_incurred.nil?
        raise ArgumentError, 'Invalid date incurred provided (date incurred cannot be nil).'
      elsif !valid_iso_format?(date_incurred)
        raise ArgumentError, 'Invalid date incurred format. Expected ISO 8601 format.'
      end
    end

    def valid_iso_format?(date_string)
      return false unless date_string.is_a?(String)

      DateTime.iso8601(date_string)
      true
    rescue ArgumentError
      false
    end

    def make_mileage_expense_request(tokens, claim_id, date_incurred, correlation_id)
      @client.add_mileage_expense(
        tokens:,
        claim_id:,
        date_incurred:,
        correlation_id:
      )
    end
  end
end
