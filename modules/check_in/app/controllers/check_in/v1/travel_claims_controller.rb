# frozen_string_literal: true

module CheckIn
  module V1
    class TravelClaimsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[create]
      after_action :after_logger, only: %i[create]
      before_action :authorize_travel_reimbursement

      def create
        check_in_session = CheckIn::V2::Session.build(
          data: { uuid: permitted_params[:uuid] },
          jwt: low_auth_token
        )

        unless check_in_session.authorized?
          render json: check_in_session.unauthorized_message, status: :unauthorized and return
        end

        submit_travel_claim(check_in_session)
      rescue Common::Exceptions::BackendServiceException => e
        render json: { success: false, errors: [e.message] }, status: e.status_code
      rescue Common::Exceptions::BadRequest => e
        render json: { success: false, errors: [e.message] }, status: :bad_request
      rescue JSON::ParserError
        render json: { success: false, errors: ['Invalid JSON format'] }, status: :bad_request
      rescue => e
        Rails.logger.error("Unexpected error in travel claims controller: #{e.class.name}")
        render json: { success: false, errors: ['Internal server error'] }, status: :internal_server_error
      end

      private

      def authorize_travel_reimbursement
        routing_error unless Flipper.enabled?('check_in_experience_travel_reimbursement')
      end

      def permitted_params
        params.require(:travel_claims).permit(:uuid, :appointment_date, :facility_type, :time_to_complete)
      end

      def submit_travel_claim(check_in_session)
        result = TravelClaim::ClaimSubmissionService.new(
          check_in: check_in_session,
          appointment_date: params[:travel_claims][:appointment_date],
          facility_type: params[:travel_claims][:facility_type],
          uuid: params[:travel_claims][:uuid]
        ).submit_claim

        render json: result, status: :ok
      end
    end
  end
end
