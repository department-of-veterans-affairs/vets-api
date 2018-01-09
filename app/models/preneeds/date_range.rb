# frozen_string_literal: true

require 'common/models/form'

module Preneeds
  class DateRange < Preneeds::Base
    attribute :from, String
    attribute :to, String

    def self.permitted_params
      [:from, :to]
    end
  end
end
