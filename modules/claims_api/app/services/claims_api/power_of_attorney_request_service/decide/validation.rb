# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class Validation
        include ActiveModel::Validations

        validate :must_be_original
        validate :declined_reason_must_be_relevant

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

        def must_be_original
          return if @previous.blank?

          errors.add :base, 'must be original'
        end

        def declined_reason_must_be_relevant
          return if @current.declined?
          return if @current.declined_reason.blank?

          errors.add :declined_reason, 'can only accompany a declination'
        end

        def raise_validation_error
          raise ::Common::Exceptions::ValidationErrors, self
        end
      end
    end
  end
end
