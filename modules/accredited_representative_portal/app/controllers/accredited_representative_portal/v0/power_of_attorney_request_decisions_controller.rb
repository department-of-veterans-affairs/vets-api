# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestDecisionsController < ApplicationController
      before_action :set_poa_request, only: :create

      ##
      # TODO: We ought to centralize our exception rendering. Starting here for
      # now.
      #
      concerning :ExceptionRendering do
        included do
          rescue_from ActiveRecord::RecordNotFound do |e|
            render(
              json: { errors: [e.message] },
              status: :not_found
            )
          end

          rescue_from ActiveRecord::RecordInvalid do |e|
            render(
              json: { errors: e.record.errors.full_messages },
              status: :unprocessable_entity
            )
          end
        end
      end

      def create
        type = deserialize_type
        reason = decision_params[:reason]

        ApplicationRecord.transaction do
          resolving = PowerOfAttorneyRequestDecision.create!(type:, creator:)

          ##
          # This form triggers the uniqueness validation, while the
          # `@poa_request.create_resolution!` form triggers a more obscure
          # `RecordNotSaved` error that is less functional for getting
          # validation errors.
          #
          PowerOfAttorneyRequestResolution.create!(
            power_of_attorney_request: @poa_request,
            resolving:,
            reason:
          )
        end

        render json: {}, status: :ok
      end

      private

      def deserialize_type
        case decision_params[:type]
        when 'acceptance'
          PowerOfAttorneyRequestDecision::Types::ACCEPTANCE
        when 'declination'
          PowerOfAttorneyRequestDecision::Types::DECLINATION
        else
          # So that validations will get their chance to complain.
          decision_params[:type]
        end
      end

      def decision_params
        params.require(:decision).permit(:type, :reason)
      end

      def creator
        current_user.user_account
      end

      def set_poa_request
        id = params[:power_of_attorney_request_id]
        @poa_request = PowerOfAttorneyRequest.find(id)
      end
    end
  end
end
