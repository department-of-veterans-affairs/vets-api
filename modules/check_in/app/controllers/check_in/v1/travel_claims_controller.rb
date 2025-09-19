# frozen_string_literal: true

module CheckIn
  module V1
    class TravelClaimsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[create]
      after_action :after_logger, only: %i[create]
      before_action :authorize_travel_reimbursement

      def create
        session = build_session
        return render_unauthorized(session) unless session.authorized?

        result = TravelClaim::ClaimSubmissionService.new(
          check_in: session,
          appointment_date: permitted_params[:appointment_date],
          facility_type: permitted_params[:facility_type],
          uuid: permitted_params[:uuid]
        ).submit_claim

        render json: result, status: :created
      rescue ActionController::ParameterMissing => e
        handle_parameter_missing_error(e)
      rescue Common::Exceptions::BackendServiceException => e
        handle_backend_service_error(e)
      end

      def permitted_params
        params.require(:travel_claims).permit(:uuid, :appointment_date, :facility_type, :time_to_complete)
      end

      private

      def build_session
        CheckIn::V2::Session.build(
          data: { uuid: permitted_params[:uuid] },
          jwt: low_auth_token
        )
      end

      def render_unauthorized(session)
        render json: session.unauthorized_message, status: :unauthorized
      end

      def authorize_travel_reimbursement
        routing_error unless Flipper.enabled?('check_in_experience_travel_reimbursement')
      end

      def handle_parameter_missing_error(exception)
        render json: {
          errors: [{ title: 'Bad Request', detail: exception.message, code: 'MISSING_PARAMETER', status: '400' }]
        }, status: :bad_request
      end

      def handle_backend_service_error(exception)
        status = map_status(exception.original_status)
        render json: {
          errors: [{
            title: 'Operation failed',
            detail: exception.response_values[:detail] || 'Travel claim operation failed',
            code: exception.key,
            status: Rack::Utils::SYMBOL_TO_STATUS_CODE[status].to_s
          }]
        }, status:
      end

      def map_status(code)
        return :unauthorized if code == 401
        return :service_unavailable if code == 429
        return :bad_request if (400..499).cover?(code)

        :bad_gateway
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
                        when 401
                          :unauthorized
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
