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

        validate :must_be_original
        validate :declined_reason_must_be_relevant

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

        private

        def must_be_original
          return if @previous.blank?

          errors.add :base, <<~MSG.squish
            must be original
          MSG
        end

        def declined_reason_must_be_relevant
          return if @current.declined?
          return if @current.declined_reason.blank?

          errors.add :declined_reason, <<~MSG.squish
            can only accompany a declination
          MSG
        end

        def raise_validation_error
          raise Error, self
        end
      end
    end
  end
end
