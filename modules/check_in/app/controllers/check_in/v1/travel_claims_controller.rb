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
          render json: check_in_session.unauthorized_message, status: :unauthorized
          return
        end

        submit_travel_claim(check_in_session)
      rescue ActionController::ParameterMissing => e
        handle_parameter_missing_error(e)
      rescue Common::Exceptions::BackendServiceException => e
        handle_backend_service_error(e)
      end

      def permitted_params
        params.require(:travel_claims).permit(:uuid, :appointment_date, :facility_type, :time_to_complete)
      end

      private

      def authorize_travel_reimbursement
        routing_error unless Flipper.enabled?('check_in_experience_travel_reimbursement')
      end

      def submit_travel_claim(check_in_session)
        result = TravelClaim::ClaimSubmissionService.new(
          check_in: check_in_session,
          appointment_date: permitted_params[:appointment_date],
          facility_type: permitted_params[:facility_type],
          uuid: permitted_params[:uuid]
        ).submit_claim

        render json: result, status: :ok
      end

      def handle_parameter_missing_error(exception)
        render json: {
          errors: [{
            title: 'Bad Request',
            detail: exception.message,
            code: 'MISSING_PARAMETER',
            status: '400'
          }]
        }, status: :bad_request
      end

      def handle_backend_service_error(exception)
        mapped_status = case exception.original_status
                        when 429
                          :service_unavailable
                        when 400..499
                          :bad_request
                        else
                          :bad_gateway
                        end

        render json: {
          errors: [{
            title: 'Operation failed',
            detail: exception.response_values[:detail] || 'Travel claim operation failed',
            code: exception.key,
            status: Rack::Utils::SYMBOL_TO_STATUS_CODE[mapped_status].to_s
          }]
        }, status: mapped_status
      end
    end
  end
end
