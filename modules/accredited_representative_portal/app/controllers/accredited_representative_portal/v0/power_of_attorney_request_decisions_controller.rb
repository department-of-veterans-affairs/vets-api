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
          set_poa_request(id)
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
          send_declination_email(@poa_request)
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

      def send_declination_email(poa_request)
        notification = poa_request.notifications.create!(type: 'declined')
        form = poa_request.power_of_attorney_form
        claimant = form.parsed_data['dependent'] || form.parsed_data['veteran']
        next unless claimant && claimant['email']

        first_name = claimant['name']['first']
        PowerOfAttorneyRequestEmailJob.perform_async(
          claimant['email'],
          Settings.vanotify.services.va_gov.template_id.appoint_a_representative_digital_submit_decline_email,
          notification.id,
          { 'first_name' => first_name }
        )
      end
    end
  end
end
