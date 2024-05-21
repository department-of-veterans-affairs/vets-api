# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class InvalidStatusTransitionError < StandardError
        def initialize(*transition)
          message = <<~HEREDOC
            Cannot transition out of terminal statuses (#{TERMINAL_STATUSES.join(', ')}).
            Transition: #{transition.join(' -> ')}
          HEREDOC

          super(message)
        end
      end

      TERMINAL_STATUSES = [
        PowerOfAttorneyRequest::Decision::Statuses::ACCEPTED,
        PowerOfAttorneyRequest::Decision::Statuses::DECLINED
      ].freeze

      class << self
        def perform(id, attrs)
          previous = PowerOfAttorneyRequest::Decision.find(id)
          current = build_decision(attrs)

          validate_status_transition!(
            previous.status,
            current.status
          )

          PowerOfAttorneyRequest::Decision.update(
            id, current
          )
        end

        private

        def validate_status_transition!(previous, current)
          return if current == previous
          return unless previous.in?(TERMINAL_STATUSES)

          raise(
            InvalidStatusTransitionError,
            previous,
            current
          )
        end

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
            # action?
            updated_at: Time.current,
            representative:
          )
        end
      end
    end
  end
end
