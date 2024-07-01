# frozen_string_literal: true

module ClaimsApi
  module PowerOfAttorneyRequestService
    module Decide
      class Validation
        include ActiveModel::Validations

        validate :must_be_original
        validate :poa_request_must_not_be_obsolete
        validate :declining_reason_can_only_accompany_a_declination

        class << self
          def perform!(...)
            new(...).validate!
          end
        end

        def initialize(poa_request, decision)
          @poa_request = poa_request
          @decision = decision
        end

        private

        def must_be_original
          return if @poa_request.decision_status.blank?

          errors.add :base, 'must be original'
        end

        def poa_request_must_not_be_obsolete
          return unless @poa_request.obsolete

          errors.add :power_of_attorney_request, 'must not be obsolete'
        end

        def declining_reason_can_only_accompany_a_declination
          return if @decision.declining?
          return if @decision.declining_reason.blank?

          errors.add :declining_reason, 'can only accompany a declination'
        end

        def raise_validation_error
          raise ::Common::Exceptions::ValidationErrors, self
        end
      end
    end
  end
end
