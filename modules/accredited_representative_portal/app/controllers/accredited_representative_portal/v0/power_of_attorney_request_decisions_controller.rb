# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestDecisionsController < ApplicationController
      include PowerOfAttorneyRequests

      before_action do
        authorize PowerOfAttorneyRequestDecision
      end

      with_options only: :create do
        before_action do
          id = params[:power_of_attorney_request_id]
          find_poa_request(id)
        end
      end

      def create
        type = deserialize_type
        reason = decision_params[:reason]

        ApplicationRecord.transaction do
          resolving = PowerOfAttorneyRequestDecision.create!(type:, creator:)
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
          log_warn(
            "Invalid decision type: #{decision_params[:type]}",
            'api.arp.poa_decision.invalid_type',
            ["invalid_type:#{decision_params[:type]}"]
          )
          decision_params[:type]
        end
      end

      def decision_params
        params.require(:decision).permit(:type, :reason)
      end

      def creator
        current_user.user_account
      end
    end
  end
end
