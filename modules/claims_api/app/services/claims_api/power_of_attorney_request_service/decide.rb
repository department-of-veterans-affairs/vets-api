# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class << self
        def perform(id, attrs)
          poa_request = PowerOfAttorneyRequest.find(id)
          decision = PowerOfAttorneyRequest::Decision.build(attrs)

          Validation.perform!(
            poa_request,
            decision
          )

          PowerOfAttorneyRequest::Decision.create(
            id, decision
          )

          return unless decision.accepting?

          UpdatePowerOfAttorney.perform(
            poa_request
          )
        end
      end
    end
  end
end
