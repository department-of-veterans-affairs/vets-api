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

        submit_travel_claim
      rescue ActionController::ParameterMissing => e
        handle_parameter_missing_error(e)
      rescue TravelClaim::Errors::InvalidArgument => e
        handle_argument_error(e)
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

      def submit_travel_claim
        result = TravelClaim::ClaimSubmissionService.new(
          appointment_date: permitted_params[:appointment_date],
          facility_type: permitted_params[:facility_type],
          check_in_uuid: permitted_params[:uuid]
        ).submit_claim

        render json: result, status: :ok
      end

      def handle_parameter_missing_error(exception)
        log_detail = error_message_for_logging(exception.message)
        Rails.logger.error('TravelClaimsController parameter missing',
                           detail: log_detail,
                           param_keys: params.to_unsafe_h.keys)
        render json: {
          errors: [{
            title: 'Bad Request',
            detail: exception.message,
            code: 'MISSING_PARAMETER',
            status: '400'
          }]
        }, status: :bad_request
      end

      def handle_argument_error(exception)
        log_detail = error_message_for_logging(exception.message)
        Rails.logger.error('TravelClaimsController invalid argument',
                           detail: log_detail)
        render json: {
          errors: [{
            title: 'Bad Request',
            detail: exception.message,
            code: 'INVALID_ARGUMENT',
            status: '400'
          }]
        }, status: :bad_request
      end

      def handle_backend_service_error(e)
        mapped = map_status(e.original_status)

        render json: {
          errors: [{
            detail: e.response_values[:detail] || 'Travel claim operation failed',
            code: e.key,
            status: mapped
          }]
        }, status: mapped
      end

      def map_status(original_status)
        case original_status
        when 400 then :bad_request
        when 401 then :unauthorized
        when 403 then :forbidden
        when 404 then :not_found
        when 409 then :conflict
        when 422 then :unprocessable_entity
        when 429 then :too_many_requests
        when 504 then :gateway_timeout
        else :bad_gateway
        end
      end

      def scrubbed_detail(detail)
        return detail unless detail.is_a?(String)

        Logging::Helper::DataScrubber.scrub(detail)
      end

      def error_message_for_logging(detail)
        return nil unless Flipper.enabled?(:check_in_experience_travel_claim_error_message_logging)

        scrubbed_detail(detail)
      end
    end
  end
end
