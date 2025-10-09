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

    validate :departure_and_arrival_locations_must_be_different
    validate :departure_date_must_be_before_arrival_date

    # Returns the expense type for flight expenses
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:airtravel]
    end

    private

    # Validates that departure and arrival locations are different
    def departure_and_arrival_locations_must_be_different
      return unless departure_location.present? && arrival_location.present?

      if departure_location.strip.casecmp?(arrival_location.strip)
        errors.add(:arrival_location, 'must be different from departure location')
      end
    end

    # Validates that departure date comes before arrival date
    def departure_date_must_be_before_arrival_date
      return unless departure_date.present? && arrival_date.present?

      errors.add(:arrival_date, 'must be after departure date') if departure_date >= arrival_date
    end
  end
end
