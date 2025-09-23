# frozen_string_literal: true

module TravelPay
  class MileageExpense < BaseExpense
    attribute :trip_type, :string
    attribute :requested_mileage, :float

    validates :trip_type, presence: true, inclusion: { in: TravelPay::Constants::TRIP_TYPES }
    validates :requested_mileage, numericality: { greater_than: 0.0 }, allow_nil: true

    # Returns the expense type for mileage expenses
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:mileage]
    end
  end
end
