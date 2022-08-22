# frozen_string_literal: true

require 'mobile/v0/exceptions/validation_errors'

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
