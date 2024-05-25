# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class Validation
        class TerminatingStatusTransitionValidator < ActiveModel::Validator
          TERMINAL_STATUSES = [
            PowerOfAttorneyRequest::Decision::Statuses::ACCEPTED,
            PowerOfAttorneyRequest::Decision::Statuses::DECLINED
          ].freeze

          NONTERMINAL_STATUSES = (
            PowerOfAttorneyRequest::Decision::Statuses::ALL -
            TERMINAL_STATUSES
          ).freeze

          def validate(record)
            return if terminating?(
              record.previous.status,
              record.current.status
            )

            record.errors.add :status, <<~MSG.squish
              Transition must be terminating:
                [#{NONTERMINAL_STATUSES.join(' | ')}] ->
                [#{TERMINAL_STATUSES.join(' | ')}]
            MSG
          end

          private

          def terminating?(previous, current)
            previous.in?(NONTERMINAL_STATUSES) &&
            current.in?(TERMINAL_STATUSES)
          end
        end
      end
    end
  end
end
