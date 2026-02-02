# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class FlightExpense < BaseExpense
    attribute :vendor_name, :string
    attribute :trip_type, :string
    attribute :departed_from, :string
    attribute :arrived_to, :string
    attribute :departure_date, :datetime
    attribute :return_date, :datetime

    validates :vendor_name, presence: true, length: { maximum: 255 }
    validates :trip_type, presence: true, inclusion: { in: TravelPay::Constants::TRIP_TYPES.values }
    validates :departed_from, presence: true, length: { maximum: 255 }
    validates :arrived_to, presence: true, length: { maximum: 255 }
    validates :departure_date, presence: true
    validates :return_date, presence: true, if: :round_trip?

    validate :departure_and_arrival_must_be_different, if: :round_trip?
    validate :departure_date_must_be_before_return_date, if: :round_trip?

    # Returns the list of permitted parameters for flight expenses
    # Extends base params with flight-specific fields
    #
    # @return [Array<Symbol>] list of permitted parameter names
    def self.permitted_params
      super + %i[vendor_name trip_type departed_from arrived_to departure_date return_date]
    end

    # Returns the expense type for flight expenses
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:airtravel]
    end

    # Returns a hash of parameters formatted for the service layer
    # Extends base params with flight-specific fields
    #
    # @return [Hash] parameters formatted for the service
    def to_service_params
      super.merge(
        'vendor_name' => vendor_name,
        'trip_type' => trip_type,
        'departed_from' => departed_from,
        'arrived_to' => arrived_to,
        'departure_date' => format_date(departure_date),
        'return_date' => format_date(return_date)
      )
    end

    private

    # Returns true if the trip type is RoundTrip
    #
    # @return [Boolean] true if trip is round trip
    def round_trip?
      trip_type == TravelPay::Constants::TRIP_TYPES[:round_trip]
    end

    # Validates that departure and arrival locations are different
    def departure_and_arrival_must_be_different
      return unless departed_from.present? && arrived_to.present?

      if departed_from.strip.casecmp?(arrived_to.strip)
        errors.add(:arrived_to, 'must be different from departure location')
      end
    end

    # Validates that departure date comes before arrival date
    def departure_date_must_be_before_return_date
      return unless departure_date.present? && return_date.present?

      errors.add(:return_date, 'must be after departure date') if departure_date.to_date > return_date.to_date
    end
  end
end
