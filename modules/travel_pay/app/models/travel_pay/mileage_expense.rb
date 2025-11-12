# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class MileageExpense < BaseExpense
    # Clear all inherited validations from BaseExpense since the Mileage expense won't
    # have purchase_date, description, or cost_requested
    clear_validators!

    attribute :trip_type, :string
    attribute :requested_mileage, :float

    validates :trip_type, presence: true, inclusion: { in: TravelPay::Constants::TRIP_TYPES.values }
    validates :requested_mileage, numericality: { greater_than: 0.0 }, allow_nil: true

    # Returns the list of permitted parameters for mileage expenses
    # Overrides base params completely since mileage doesn't use base expense fields
    #
    # @return [Array<Symbol>] list of permitted parameter names
    def self.permitted_params
      %i[trip_type requested_mileage receipt]
    end

    # Returns the expense type for mileage expenses
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:mileage]
    end
  end
end
