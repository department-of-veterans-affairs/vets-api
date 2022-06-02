# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class Immunizations < PaginationBase
        params do
          optional(:use_cache).maybe(:bool, :filled?)
        end
      end
    end
  end
end
