# frozen_string_literal: true

module TravelPay
  class InvalidComparableError < StandardError
    def initialize(msg, comparable)
      @comparable = comparable
      super(msg)
    end
  end
end
