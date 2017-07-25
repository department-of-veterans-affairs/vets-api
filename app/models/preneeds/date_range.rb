# frozen_string_literal: true
require 'common/models/form'

module Preneeds
  class DateRange < Preneeds::Base
    attribute :from, String
    attribute :to, String

    def self.permitted_params
      attribute_set.map { |a| a.name.to_sym }
    end
  end
end
