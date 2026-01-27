# frozen_string_literal: true

require_relative '../../../lib/travel_pay/constants'
module TravelPay
  module ExpenseNormalizer
    # Normalizes expense data by overwriting expenseType with name for Parking expenses
    # This corrects the TP API response where the Parking expenseType is returned as "Other"
    #
    # @param expense [Hash] Single expense hash
    # @return [Hash] The normalized expense
    def normalize_expense(expense)
      return expense unless expense.is_a?(Hash)

      expense['expenseType'] = expense['name'] if expense['name']&.downcase == 'parking'

      if expense['expenseType'] == 'CommonCarrier'
        expense['reasonNotUsingPOV'] =
          normalize_reason_not_using_pov(expense['reasonNotUsingPOV'])
      end
      expense
    end

    # Normalizes an array of expenses
    #
    # @param expenses [Array<Hash>] Array of expense hashes
    # @return [Array<Hash>] Array of normalized expenses
    def normalize_expenses(expenses)
      return expenses unless expenses.is_a?(Array)

      expenses.each do |expense|
        normalize_expense(expense)
      end
    end

    def normalize_reason_not_using_pov(value)
      return value if TravelPay::Constants::COMMON_CARRIER_EXPLANATIONS.value?(value)

      key = value.to_s.underscore.to_sym
      TravelPay::Constants::COMMON_CARRIER_EXPLANATIONS[key] || value
    end
  end
end
