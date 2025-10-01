# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class TollExpense < BaseExpense
    attribute :vendor_name, :string

    # Strip whitespace before validation
    before_validation :strip_vendor_name

    validates :vendor_name, presence: true, length: { minimum: 1 }

    # Override expense_type for MealExpense
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:meal]
    end

    private

    def strip_vendor_name
      self.vendor_name = vendor_name&.strip
    end
  end
end
