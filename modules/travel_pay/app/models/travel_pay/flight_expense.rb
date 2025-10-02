# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class FlightExpense < BaseExpense
    attribute :vendor, :string
    attribute :trip_type, :string
    attribute :departure_location, :string
    attribute :arrival_location, :string
    attribute :departure_date, :datetime
    attribute :arrival_date, :datetime

    validates :vendor, presence: true, length: { maximum: 255 }
    validates :trip_type, presence: true, inclusion: { in: TravelPay::Constants::TRIP_TYPES.values }
    validates :departure_location, presence: true, length: { maximum: 255 }
    validates :arrival_location, presence: true, length: { maximum: 255 }
    validates :departure_date, presence: true
    validates :arrival_date, presence: true

    # Returns the expense type for flight expenses
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:airtravel]
    end
  end
end
