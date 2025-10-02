# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class CommonCarrierExpense < BaseExpense
    # POV = Privately Owned Vehicle
    attribute :reason_not_using_pov, :string
    attribute :carrier_type, :string

    validates :reason_not_using_pov, presence: true, inclusion: { in: TravelPay::Constants::COMMON_CARRIER_EXPLANATIONS.values }
    validates :carrier_type, presence: true, inclusion: { in: TravelPay::Constants::COMMON_CARRIER_TYPES.values }

    # Returns the expense type for common carrier expenses
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:common_carrier]
    end
  end
end
