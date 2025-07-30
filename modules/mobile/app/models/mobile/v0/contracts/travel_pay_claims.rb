# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class TravelPayClaims < Base
        params do
          required(:start_date).filled(:string)
          required(:end_date).filled(:string)
          optional(:page_number).filled(:integer)
        end
      end
    end
  end
end
