# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class Base < Dry::Validation::Contract
        def call(input)
          result = super(input.to_h.symbolize_keys)
          raise Mobile::V0::Exceptions::ValidationErrors, result if result.failure?

          result
        end
      end
    end
  end
end
