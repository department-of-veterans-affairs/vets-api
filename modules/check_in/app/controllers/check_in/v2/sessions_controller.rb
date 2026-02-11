# frozen_string_literal: true

module CheckIn
  module V2
    class SessionsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[show create]
      after_action :after_logger, only: %i[show create]

      def show
        check_in_session = CheckIn::V2::Session.build(data: { uuid: params[:id] }, jwt: low_auth_token)

        render json: check_in_session.client_error, status: :ok and return unless check_in_session.valid_uuid?

        ::V2::Chip::Service.build(check_in: check_in_session).refresh_precheckin if pre_checkin?

        render json: check_in_session.unauthorized_message, status: :ok and return unless check_in_session.authorized?

        render json: check_in_session.success_message
      end

      def create
        check_in_session = CheckIn::V2::Session.build(data: permitted_params, jwt: low_auth_token)

        render json: check_in_session.client_error, status: :bad_request and return unless check_in_session.valid?
        render json: check_in_session.success_message and return if check_in_session.authorized?

        log_session_creation_attempt(check_in_session) if Flipper.enabled?(:check_in_experience_detailed_logging)
        token_data = ::V2::Lorota::Service.build(check_in: check_in_session).token

        ::V2::Chip::Service.build(check_in: check_in_session).set_precheckin_started if pre_checkin?

        self.low_auth_token = token_data[:jwt]
        render json: token_data[:permission_data]
      end

      def permitted_params
        params.require(:session).permit(:uuid, :dob, :last_name, :check_in_type, :facility_type)
      end

      private

      def pre_checkin?
        check_in_param = params[:checkInType] # GET request
        check_in_param = params.dig(:session, :check_in_type) if check_in_param.nil?
        check_in_param == 'preCheckIn'
      end

      def log_session_creation_attempt(session)
        Rails.logger.info({
                            message: 'Check-in session creation',
                            check_in_uuid: session.uuid,
                            check_in_type: session.check_in_type,
                            facility_type: session.facility_type,
                            workflow: pre_checkin? ? 'Pre-Check-In' : 'Day-Of-Check-In'
                          })
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_enabled')
      end
    end
  end
end
