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

    # Returns the list of permitted parameters for meal expenses
    # Extends base params with meal-specific fields
    #
    # @return [Array<Symbol>] list of permitted parameter names
    def self.permitted_params
      super + %i[vendor_name]
    end

    # Override expense_type for MealExpense
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:meal]
    end

    # Returns a hash of parameters formatted for the service layer
    # Extends base params with meal-specific fields
    #
    # @return [Hash] parameters formatted for the service
    def to_service_params
      super.merge('vendor_name' => vendor_name)
    end
  end
end
