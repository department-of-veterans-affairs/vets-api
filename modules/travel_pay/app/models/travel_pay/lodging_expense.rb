# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class LodgingExpense < BaseExpense
    attribute :vendor, :string
    attribute :check_in_date, :date
    attribute :check_out_date, :date

    # Strip whitespace on assignment to ensure validations catch empty/whitespace values
    def vendor=(value)
      super(value&.strip)
    end

    validates :vendor, presence: true, length: { minimum: 1 }
    validates :check_in_date, presence: true
    validates :check_out_date, presence: true
    validate :check_out_after_check_in

    # Override expense_type for LodgingExpense
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:lodging]
    end

    private

    # This validation ensures check_out_date is after check_in_date
    def check_out_after_check_in
      return unless check_in_date.present? && check_out_date.present?

      if check_out_date <= check_in_date
        errors.add(:check_out_date, 'must be after check-in date')
        errors.add(:check_in_date, 'must be before check-out date')
      end
    end
  end
end
