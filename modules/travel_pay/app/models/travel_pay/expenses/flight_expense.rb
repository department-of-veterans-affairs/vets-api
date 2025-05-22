# frozen_string_literal: true

module TravelPay
  class FlightExpense < Travelpay::Expense
    include Spannable

    attr_accessor :vendor, :trip_type, :departure_location, :arrival_location

    module TripType
      ROUND_TRIP = :round_trip
      ONE_WAY = :one_way
      ALL = [ROUND_TRIP, ONE_WAY]
    end

    validates :vendor, :trip_type, :departure_location, :arrival_location, presence: true
    validate :trip_type_valid

    def initialize(vendor:, trip_type:, departure_location:, arrival_location:, **kwargs)
      super(**kwargs)
      @vendor = vendor
      @trip_type = trip_type
      @departure_location = departure_location
      @arrival_location = arrival_location
    end

    def trip_type_valid
      # Add other date validations
      # Purchase date before 'from'?
      
      unless is_ordered?
        errors.add(:from, 'is before or equal to :to')
      end

      unless TripType::ALL.include?(trip_type)
        errors.add(:trip_type, "must be one of #{TripType::ALL.join(', ')}")
      end
    end
  end
end
