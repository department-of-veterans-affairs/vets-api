# frozen_string_literal: true

module TravelPay
  class MileageExpense < BaseExpense
    VALID_TRIP_TYPES = %w[OneWay RoundTrip Unspecified].freeze

    attribute :trip_type, :string
    attribute :requested_mileage, :float

    validates :trip_type, presence: true, inclusion: { in: VALID_TRIP_TYPES }
    validates :requested_mileage, numericality: { greater_than: 0.0 }, allow_nil: true

    # Returns the expense type for mileage expenses
    #
    # @return [String] the expense type
    def expense_type
      'mileage'
    end
  end
end
