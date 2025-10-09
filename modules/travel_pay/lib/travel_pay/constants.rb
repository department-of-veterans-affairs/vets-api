# frozen_string_literal: true

module TravelPay
  module Constants
    # Usage:
    # TravelPay::Constants::BASE_EXPENSE_PATHS[:meal]
    BASE_EXPENSE_PATHS = {
      airtravel: 'api/v1/expenses/airtravel',
      meal: 'api/v1/expenses/meal',
      mileage: 'api/v2/expenses/mileage',
      parking: 'api/v1/expenses/parking',
      other: 'api/v1/expenses/other',
      toll: 'api/v1/expenses/toll'
    }.freeze

    # Usage:
    # TravelPay::Constants::EXPENSE_TYPES[:parking]
    EXPENSE_TYPES = {
      airtravel: 'airtravel',
      meal: 'meal',
      mileage: 'mileage',
      parking: 'parking',
      other: 'other',
      toll: 'toll'
    }.freeze

    # Usage:
    # TravelPay::Constants::TRIP_TYPES[:one_way]
    TRIP_TYPES = {
      one_way: 'OneWay',
      round_trip: 'RoundTrip',
      unspecified: 'Unspecified'
    }.freeze

    # Usage:
    # TravelPay::Constants::UUID_REGEX.match?(uuid_string)
    UUID_REGEX = /\A[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[89ABCD][0-9A-F]{3}-[0-9A-F]{12}\z/i
  end
end
