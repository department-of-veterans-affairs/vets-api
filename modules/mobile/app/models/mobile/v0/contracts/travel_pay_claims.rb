# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class TravelPayClaims < PaginationBase
        RequiredDateRangeSchema = Dry::Schema.Params do
          required(:start_date).filled(:date)
          required(:end_date).filled(:date)
        end

        params(RequiredDateRangeSchema)
      end
    end
  end
end 