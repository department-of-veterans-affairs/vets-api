# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class << self
        def perform(id, attrs)
          metadata = PowerOfAttorneyRequest::Metadata.find(id)
          decision = PowerOfAttorneyRequest::Decision.build(attrs)

          Validation.perform!(
            metadata,
            decision
          )

          PowerOfAttorneyRequest::Decision.create(
            id, decision
          )
        end
      end
    end
  end
end
