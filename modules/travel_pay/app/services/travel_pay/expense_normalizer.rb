# frozen_string_literal: true

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
  end
end
