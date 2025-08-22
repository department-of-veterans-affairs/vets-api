# frozen_string_literal: true

module CheckIn
  module V2
    class TravelClaimsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[create]
      after_action :after_logger, only: %i[create]

      ##
      # Submits a travel claim using the V3 API endpoint.
      # This is a synchronous endpoint that does not use background jobs or polling.
      #
      def create
        check_in_session = CheckIn::V2::Session.build(data: { uuid: permitted_params[:uuid] }, jwt: low_auth_token)

        unless check_in_session.authorized?
          render json: check_in_session.unauthorized_message, status: :unauthorized and return
        end

        auth_manager = TravelClaim::AuthManager.new(check_in_session:)
        appointments_service = TravelClaim::AppointmentsService.new(
          check_in_session:,
          auth_manager:
        )

        result = appointments_service.submit_claim_v3(
          claim_id: permitted_params[:claim_id],
          correlation_id: permitted_params[:correlation_id] || SecureRandom.uuid
        )

        logger.info({ message: 'Successfully submitted V3 travel claim', uuid: permitted_params[:uuid] })

        render json: { data: result[:data] }, status: :ok
      rescue ActionController::ParameterMissing => e
        logger.error({ message: 'V3 travel claim parameter missing', error: e.message })
        render json: { error: e.message }, status: :bad_request
      rescue ArgumentError => e
        logger.error({ message: 'V3 travel claim validation error', error: e.message, uuid: permitted_params[:uuid] })
        render json: { error: e.message }, status: :bad_request
      rescue Common::Exceptions::BackendServiceException => e
        logger.error({ message: 'V3 travel claim API error', error: e.message, uuid: permitted_params[:uuid] })
        render json: { error: 'Travel claim submission failed' }, status: :unprocessable_entity
      rescue => e
        logger.error({ message: 'Unexpected V3 travel claim error', error: e.message, uuid: permitted_params[:uuid] })
        render json: { error: 'Internal server error' }, status: :internal_server_error
      end

      private

      def permitted_params
        params.require(:travel_claims).permit(:uuid, :claim_id, :correlation_id)
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_travel_reimbursement')
      end
    end
  end
end
