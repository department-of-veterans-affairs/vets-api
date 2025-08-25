# frozen_string_literal: true

module TravelClaim
  ##
  # Client for Travel Claim mileage expense API operations.
  #
  class MileageExpenseClient < BaseClient
    EXPENSE_DESCRIPTION = 'mileage'
    TRIP_TYPE = 'RoundTrip'

    ##
    # Adds a mileage expense to an existing travel claim.
    #
    # @param tokens [Hash] Authentication tokens hash
    # @param claim_id [String] UUID of the travel claim to add the expense to
    # @param date_incurred [String] ISO 8601 formatted date when the expense was incurred
    # @param correlation_id [String] Request correlation ID
    # @return [Faraday::Response] HTTP response containing expense data
    #
    def add_mileage_expense(tokens:, claim_id:, date_incurred:, correlation_id:)
      body = build_mileage_expense_body(claim_id:, date_incurred:)
      headers = build_standard_headers(tokens, correlation_id)

      full_url = "#{settings.claims_base_path}/api/v3/expenses/mileage"
      perform(:post, full_url, body, headers)
    end

    private

    ##
    # Builds the request body for the mileage expense API call.
    #
    # @param claim_id [String] UUID of the travel claim
    # @param date_incurred [String] ISO 8601 formatted date when the expense was incurred
    # @return [Hash] Request body hash
    #
    def build_mileage_expense_body(claim_id:, date_incurred:)
      {
        claimId: claim_id,
        dateIncurred: date_incurred,
        description: EXPENSE_DESCRIPTION,
        tripType: TRIP_TYPE
      }
    end
  end
end
