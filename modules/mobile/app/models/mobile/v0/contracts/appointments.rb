# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class Appointments < PaginationBase
        params(Schemas::DateRangeSchema) do
          optional(:use_cache).maybe(:bool, :filled?)
          optional(:reverse_sort).maybe(:bool, :filled?)
          optional(:included).maybe(:array, :filled?)
          optional(:include).maybe(:array, :filled?)
        end
      end
    end
  end
end
