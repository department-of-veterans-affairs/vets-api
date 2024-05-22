# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class Validation
        class Error < ::Common::Exceptions::ValidationErrors
          def i18n_key
            'common.exceptions.validation_errors'
          end
        end

        include ActiveModel::Validations

        validate :status_transition_must_be_terminating

        class << self
          def perform!(...)
            new(...).validate!
          end
        end

        def initialize(previous, current)
          @previous = previous
          @current = current
        end

        private

        TERMINAL_STATUSES = [
          PowerOfAttorneyRequest::Decision::Statuses::ACCEPTED,
          PowerOfAttorneyRequest::Decision::Statuses::DECLINED
        ].freeze

        NONTERMINAL_STATUSES = (
          PowerOfAttorneyRequest::Decision::Statuses::ALL -
          TERMINAL_STATUSES
        ).freeze

        def status_transition_must_be_terminating
          return if
            # Genuine decisions are okay once but then frozen.
            @previous.status.in?(NONTERMINAL_STATUSES) &&
            @current.status.in?(TERMINAL_STATUSES)

          message =
            'Transition must be terminating: ' \
            "[#{NONTERMINAL_STATUSES.join(' | ')}] -> [#{TERMINAL_STATUSES.join(' | ')}]"

          errors.add(:status, message)
        end

        def raise_validation_error
          raise Error, self
        end
      end
    end
  end
end
