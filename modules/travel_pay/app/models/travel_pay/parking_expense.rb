# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class ParkingExpense < BaseExpense
    # Override expense_type for ParkingExpense
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:parking]
    end
  end
end
