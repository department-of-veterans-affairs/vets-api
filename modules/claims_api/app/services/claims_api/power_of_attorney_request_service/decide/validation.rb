# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class Validation
        include ActiveModel::Validations

        validate :must_be_original
        validate :power_of_attorney_request_must_not_be_obsolete
        validate :declined_reason_must_be_relevant

        class << self
          def perform!(...)
            new(...).validate!
          end
        end

        def initialize(metadata, decision)
          @metadata = metadata
          @decision = decision
        end

        private

        def must_be_original
          return if @metadata.decision_status.blank?

          errors.add :base, 'must be original'
        end

        def power_of_attorney_request_must_not_be_obsolete
          return unless @metadata.obsolete

          errors.add :power_of_attorney_request, 'must not be obsolete'
        end

        def declined_reason_must_be_relevant
          return if @decision.declined?
          return if @decision.declined_reason.blank?

          errors.add :declined_reason, 'can only accompany a declination'
        end

        def raise_validation_error
          raise ::Common::Exceptions::ValidationErrors, self
        end
      end
    end
  end
end
