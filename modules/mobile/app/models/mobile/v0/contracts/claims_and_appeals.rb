# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class ClaimsAndAppeals < PaginationBase
        params(Schemas::DateRangeSchema) do
          optional(:use_cache).maybe(:bool, :filled?)
          optional(:show_completed).maybe(:bool, :filled?)
        end
      end
    end
  end
end
