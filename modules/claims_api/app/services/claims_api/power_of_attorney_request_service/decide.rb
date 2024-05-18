# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    # TODO: Error handling.
    module Decide
      class << self
        def perform(id, params)
          attrs = params.deep_transform_keys(&:underscore)

          representative =
            PowerOfAttorneyRequest::Decision::Representative.new(
              **attrs.delete(:representative)
            )

          decision =
            PowerOfAttorneyRequest::Decision.new(
              **attrs,
              # Assign `updated_at` somewhere more obvious?
              updated_at: Time.current,
              representative:
            )

          PowerOfAttorneyRequest::Decision.update(
            id, decision
          )
        end
      end
    end
  end
end
