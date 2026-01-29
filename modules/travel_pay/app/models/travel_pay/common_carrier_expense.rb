# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'

module TravelPay
  class CommonCarrierExpense < BaseExpense
    include ActiveModel::Validations::Callbacks

    # POV = Privately Owned Vehicle
    attribute :reason_not_using_pov, :string
    attribute :carrier_type, :string

    validates :reason_not_using_pov, presence: true, inclusion: { in: TravelPay::Constants::COMMON_CARRIER_EXPLANATIONS.values }
    validates :carrier_type, presence: true, inclusion: { in: TravelPay::Constants::COMMON_CARRIER_TYPES.values }

    # Normalize snake_case inputs before validation
    before_validation :normalize_reason_not_using_pov

    # Returns the list of permitted parameters for common carrier expenses
    # Extends base params with common carrier-specific fields
    #
    # @return [Array<Symbol>] list of permitted parameter names
    def self.permitted_params
      super + %i[reason_not_using_pov carrier_type]
    end

    # Returns the expense type for common carrier expenses
    #
    # @return [String] the expense type
    def expense_type
      TravelPay::Constants::EXPENSE_TYPES[:commoncarrier]
    end

    # Returns a hash of parameters formatted for the service layer
    # Extends base params with common carrier-specific fields
    #
    # @return [Hash] parameters formatted for the service
    def to_service_params
      super.merge(
        'reason_not_using_pov' => reason_not_using_pov,
        'carrier_type' => carrier_type
      )
    end

    def normalize_reason_not_using_pov
      return if reason_not_using_pov.blank?

      mapping = TravelPay::Constants::COMMON_CARRIER_EXPLANATIONS
      key = reason_not_using_pov.to_s.underscore.to_sym
      self.reason_not_using_pov = mapping[key] if mapping.key?(key)
    end
  end
end
