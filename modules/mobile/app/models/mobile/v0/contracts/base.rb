# frozen_string_literal: true

module Mobile
  module V0
    module Contracts
      class Base < Dry::Validation::Contract
        def call(input)
          super(input.to_h.symbolize_keys)
        end
      end
    end
  end
end
