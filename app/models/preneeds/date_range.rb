# frozen_string_literal: true

module Preneeds
  # Models a date range from a {Preneeds::BurialForm} form
  #
  # @!attribute from
  #   @return [String] 'from' date
  # @!attribute to
  #   @return [String] 'to' date
  #
  class DateRange < Preneeds::Base
    attr_accessor :from, :to

    # (see Preneeds::Applicant.permitted_params)
    #
    def self.permitted_params
      %i[from to]
    end
  end
end
