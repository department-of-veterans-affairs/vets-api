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
          raise UnprocessableEntity, 'Reason must be blank' if reason.present?

          service = PowerOfAttorneyRequestService::Accept.new(@poa_request, creator, reason)
          poa_form_submission = service.call
          raise UnprocessableEntity, poa_form_submission.error_message if poa_form_submission.enqueue_failed?
        when 'declination'
          PowerOfAttorneyRequestService::Decline.new(@poa_request, creator, reason).call
        else
          raise UnprocessableEntity, 'Invalid type parameter - Types accepted: [acceptance declination]'
        end

        render json: {}, status: :ok
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
