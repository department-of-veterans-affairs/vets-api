# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class TollExpense < BaseExpense
    attribute :vendor_name, :string

    validates :vendor_name, presence: true, length: { minimum: 1 }

    # Override expense_type for MealExpense
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:meal]
    end
  end
end
