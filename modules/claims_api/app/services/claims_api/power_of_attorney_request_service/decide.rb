# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class << self
        def perform(id, attrs)
          previous = PowerOfAttorneyRequest::Decision.find(id)
          current = build_decision(attrs)

          Validation.perform!(
            previous,
            current
          )

          PowerOfAttorneyRequest::Decision.create(
            id, current
          )
        end

        private

        # Should hydrating our models from user params be integrated into the
        # model layer like it is in `ActiveModel`?
        def build_decision(attrs)
          representative =
            PowerOfAttorneyRequest::Decision::Representative.new(
              **attrs.delete(:representative)
            )

          PowerOfAttorneyRequest::Decision.new(
            **attrs,
            # Assign `updated_at` somewhere more obvious near the actual update
            # event?
            updated_at: Time.current,
            representative:
          )
        end
      end
    end
  end
end
