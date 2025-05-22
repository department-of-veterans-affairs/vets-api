# frozen_string_literal: true

module TravelPay
  class LodgingExpense < TravelPay::Expense
    include Spannable

    attr_accessor :vendor

    validates :vendor, presence: true

    def initialize(vendor:, **kwargs)
      super(**kwargs)
      @vendor = vendor
    end
  end
end
