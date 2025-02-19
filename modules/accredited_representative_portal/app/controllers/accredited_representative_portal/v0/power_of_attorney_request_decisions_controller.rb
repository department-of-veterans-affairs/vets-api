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
        reason = decision_params[:reason]

        case decision_params[:type]
        when 'acceptance'
          PowerOfAttorneyRequestService::Accept.new(@poa_request, creator, reason).call
          render json: {}, status: :ok
        when 'declination'
          @poa_request.mark_declined!(creator, reason)
          render json: {}, status: :ok
        else
          render json: {
            errors: ['Invalid type parameter - Types accepted: [acceptance declination]']
          }, status: :bad_request
        end
      rescue PowerOfAttorneyRequestService::Accept::Error => e
        render json: { errors: [e.message] }, status: e.status
      end

      private

      def decision_params
        params.require(:decision).permit(:type, :reason)
      end

      def creator
        current_user.user_account
      end
    end
  end
end
