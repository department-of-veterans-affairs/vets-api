# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class TollExpense < BaseExpense
    # Override expense_type for TollExpense
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:toll]
    end
  end
end
