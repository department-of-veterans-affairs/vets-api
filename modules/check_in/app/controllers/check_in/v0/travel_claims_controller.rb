# frozen_string_literal: true

module CheckIn
  module V0
    class TravelClaimsController < CheckIn::ApplicationController
      def create
        check_in_session = CheckIn::V2::Session.build(data: { uuid: permitted_params[:uuid] }, jwt: low_auth_token)

        unless check_in_session.authorized?
          render json: check_in_session.unauthorized_message, status: :unauthorized and return
        end

        TravelClaimSubmissionWorker.perform_async(permitted_params[:uuid], permitted_params[:appointment_date])

        render nothing: true, status: :accepted
      end

      def permitted_params
        params.require(:travel_claims).permit(:uuid, :appointment_date)
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_travel_reimbursement')
      end
    end
  end
end
