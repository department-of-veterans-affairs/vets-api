# frozen_string_literal: true

require_relative 'expense'

module TravelPay
  class CommonCarrierExpense < TravelPay::Expense
    attr_accessor :reason, :explanation, :type

    module Explanation
      PRIVATE_VEHICLE_UNAVAILABLE = :private_vehicle_unavailable
      MEDICALLY_INDICATED = :medically_indicated
      OTHER = :other
      ALL = [PRIVATE_VEHICLE_UNAVAILABLE, MEDICALLY_INDICATED, OTHER]
    end

    module Type
      BUS = :bus
      SUBWAY = :subway
      TAXI = :taxi
      TRAIN = :train
      OTHER = :other
      ALL = [BUS, SUBWAY, TAXI, TRAIN, OTHER]
    end

    validates :reason, :explanation, :type, presence: true
    validate :explanation_valid
    validate :type_valid

    def initialize(reason:, explanation:, type:, **kwargs)
      super(**kwargs)
      @reason = reason
      @explanation = explanation
      @type = type
    end

    def explanation_valid
      unless Explanation::ALL.include?(explanation)
        errors.add(:explanation, "must be one of #{Explanation::ALL.join(', ')}")
      end
    end

    def type_valid
      unless Type::ALL.include?(type)
        errors.add(:type, "must be one of #{Type::ALL.join(', ')}")
      end
    end
  end
end
