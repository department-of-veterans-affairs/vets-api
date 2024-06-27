# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class << self
        def perform(id, attrs)
          previous = PowerOfAttorneyRequest::Decision.find(id)
          current = PowerOfAttorneyRequest::Decision.build(attrs)

          Validation.perform!(
            previous,
            current
          )

          PowerOfAttorneyRequest::Decision.create(
            id, current
          )
        end
      end
    end
  end
end
