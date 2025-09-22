# frozen_string_literal: true

module TravelPay
  module Constants
    # Usage:
    # TravelPay::Constants::BASE_EXPENSE_PATHS[:meal]
    BASE_EXPENSE_PATHS = {
      meal: 'api/v1/expenses/meal',
      mileage: 'api/v2/expenses/mileage',
      parking: 'api/v1/expenses/parking',
      other: 'api/v1/expenses/other'
    }.freeze

    # Usage:
    # TravelPay::Constants::EXPENSE_TYPES[:parking]
    EXPENSE_TYPES = {
      meal: 'meal',
      mileage: 'mileage',
      parking: 'parking',
      other: 'other'
    }.freeze

    # Usage:
    # TravelPay::Constants::UUID_REGEX.match?(uuid_string)
    UUID_REGEX = /\A[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[89ABCD][0-9A-F]{3}-[0-9A-F]{12}\z/i
  end
end