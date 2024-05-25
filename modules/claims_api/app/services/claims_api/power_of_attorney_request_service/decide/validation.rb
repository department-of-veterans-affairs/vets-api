# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class Validation
        # This error type expects to be instantiated with objects that are
        # `ActiveModel::Validations`.
        class Error < ::Common::Exceptions::ValidationErrors
          def i18n_key
            'common.exceptions.validation_errors'
          end
        end

        include ActiveModel::Validations

        # Only genuine decisions are allowed and they are only allowed once.
        validates_with TerminatingStatusTransitionValidator

        class << self
          def perform!(...)
            new(...).validate!
          end
        end

        attr_reader :previous, :current

        def initialize(previous, current)
          @previous = previous
          @current = current
        end

        def raise_validation_error
          raise Error, self
        end
      end
    end
  end
end
