# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class PaymentHistory < PaginationBase
        params(Schemas::DateRangeSchema) do
          optional(:reverse_sort).maybe(:bool, :filled?)
        end
      end
    end
  end
end
