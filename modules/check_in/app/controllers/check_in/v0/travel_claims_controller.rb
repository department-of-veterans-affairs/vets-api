# frozen_string_literal: true

module CheckIn
  module V0
    class TravelClaimsController < CheckIn::ApplicationController
      def create
        check_in_session = CheckIn::V2::Session.build(data: { uuid: permitted_params[:uuid] }, jwt: low_auth_token)

        unless check_in_session.authorized?
          render json: check_in_session.unauthorized_message, status: :unauthorized and return
        end

        claims_resp = TravelClaim::Service.build(check_in: check_in_session, params: permitted_params).submit_claim
        render json: claims_resp, status: claims_resp[:status]
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
