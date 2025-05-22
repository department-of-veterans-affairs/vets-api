# frozen_string_literal: true

module TravelPay
  class TollExpense < TravelPay::Expense
    # no unique expense fields
    def initialize(**kwargs)
      super(**kwargs)
    end
  end
end
