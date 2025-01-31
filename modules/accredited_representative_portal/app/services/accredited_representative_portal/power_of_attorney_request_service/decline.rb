# frozen_string_literal: true

module AccreditedRepresentativePortal
  module PowerOfAttorneyRequestService
    class Decline
      attr_reader :poa_request, :creator, :reason

      def initialize(poa_request, creator, reason)
        @poa_request = poa_request
        @creator = creator
        @reason = reason
      end

      def call
        ApplicationRecord.transaction do
          resolving = PowerOfAttorneyRequestDecision.create!(
            type: PowerOfAttorneyRequestDecision::Types::DECLINATION, creator:
          )
          ##
          # This form triggers the uniqueness validation, while the
          # `@poa_request.create_resolution!` form triggers a more obscure
          # `RecordNotSaved` error that is less functional for getting
          # validation errors.
          #
          PowerOfAttorneyRequestResolution.create!(
            power_of_attorney_request: poa_request,
            resolving:,
            reason:
          )
        end
      end
    end
  end
end
