# frozen_string_literal: true

# Include this module when your type has a date range
module TravelPay
  module Spannable
    attr_accessor :from, :to

    def is_ordered?
      # Guess: returns true if from <= to
      from && to && from <= to
    end

    def is_in_range?(date)
      # Guess: returns true if date is between from and to (inclusive)
      from && to && date && (from..to).cover?(date)
    end
  end
end
