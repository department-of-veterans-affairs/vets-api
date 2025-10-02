# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class LodgingExpense < BaseExpense
    attribute :vendor, :string
    attribute :check_in_date, :date
    attribute :check_out_date, :date

    # Strip whitespace on assignment to ensure validations catch empty/whitespace values
    def vendor=(value)
      super(value&.strip)
    end

    validates :vendor, presence: true, length: { minimum: 1 }
    validates :check_in_date, presence: true
    validates :check_out_date, presence: true

    # Override expense_type for MealExpense
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:lodging]
    end
  end
end
