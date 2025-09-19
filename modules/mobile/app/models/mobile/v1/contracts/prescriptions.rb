# frozen_string_literal: true

module Mobile
  module V1
    module Contracts
      # Mirrors V0 pagination & optional params behavior; can diverge later if V1 needs different rules.
      class Prescriptions < Mobile::V0::Contracts::PaginationBase
        params do
          optional(:filter).maybe(:hash, :filled?)
          optional(:sort).maybe(:string, :filled?)
        end
      end
    end
  end
end
