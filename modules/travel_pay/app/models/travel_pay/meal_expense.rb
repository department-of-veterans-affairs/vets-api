# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class MealExpense < BaseExpense
    attribute :vendor_name, :string

    # Strip whitespace on assignment to ensure validations catch empty/whitespace values
    def vendor_name=(value)
      super(value&.strip)
    end

    validates :vendor_name, presence: true, length: { minimum: 1 }

    # Override expense_type for MealExpense
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:meal]
    end
  end
end
