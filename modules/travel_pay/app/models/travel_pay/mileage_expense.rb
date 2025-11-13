# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class MileageExpense < BaseExpense
    # Clear all inherited validations from BaseExpense since the Mileage expense won't
    # have description or cost_requested
    clear_validators!

    attribute :trip_type, :string
    attribute :requested_mileage, :float

    validates :purchase_date, presence: true
    validates :trip_type, presence: true, inclusion: { in: TravelPay::Constants::TRIP_TYPES.values }
    validates :requested_mileage, numericality: { greater_than: 0.0 }, allow_nil: true

    # Returns the list of permitted parameters for mileage expenses
    # Overrides base params completely since mileage doesn't use description or cost_requested
    #
    # @return [Array<Symbol>] list of permitted parameter names
    def self.permitted_params
      %i[purchase_date trip_type requested_mileage]
    end

    # Returns the expense type for mileage expenses
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:mileage]
    end

    # Returns a hash of parameters formatted for the service layer
    # Overrides base implementation since mileage has different params
    #
    # @return [Hash] parameters formatted for the service
    def to_service_params
      params = {
        'expense_type' => expense_type,
        'purchase_date' => format_date(purchase_date),
        'trip_type' => trip_type,
        'requested_mileage' => requested_mileage
      }
      params['claim_id'] = claim_id if claim_id.present?
      params
    end
  end
end
