# frozen_string_literal: true

module Preneeds
  class DateRange < Preneeds::Base
    attribute :from, String
    attribute :to, String

    def self.permitted_params
      %i[from to]
    end
  end
end
