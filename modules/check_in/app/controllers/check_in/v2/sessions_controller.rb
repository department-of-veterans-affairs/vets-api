# frozen_string_literal: true

module CheckIn
  module V2
    class SessionsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[show create], if: :additional_logging?
      after_action :after_logger, only: %i[show create], if: :additional_logging?

      def show
        check_in_session = CheckIn::V2::Session.build(data: { uuid: params[:id] }, jwt: low_auth_token)

        render json: check_in_session.client_error, status: :ok and return unless check_in_session.valid_uuid?

        if Flipper.enabled?('check_in_experience_refresh_pre_checkin') && pre_checkin?
          ::V2::Chip::Service.build(check_in: check_in_session).refresh_precheckin
        end

        render json: check_in_session.unauthorized_message, status: :ok and return unless check_in_session.authorized?

        render json: check_in_session.success_message
      end

      def create
        check_in_session = CheckIn::V2::Session.build(data: permitted_params, jwt: low_auth_token)

        render json: check_in_session.client_error, status: :bad_request and return unless check_in_session.valid?
        render json: check_in_session.success_message and return if check_in_session.authorized?

        token_data = ::V2::Lorota::Service.build(check_in: check_in_session).token

        if Flipper.enabled?('check_in_experience_set_pre_checkin_status') && pre_checkin?
          ::V2::Chip::Service.build(check_in: check_in_session).set_precheckin_started
        end

        self.low_auth_token = token_data[:jwt]
        render json: token_data[:permission_data]
      end

      def permitted_params
        if Flipper.enabled?('check_in_experience_lorota_security_updates_enabled')
          params.require(:session).permit(:uuid, :dob, :last_name, :check_in_type)
        else
          params.require(:session).permit(:uuid, :last4, :last_name, :check_in_type)
        end
      end

      private

      def pre_checkin?
        check_in_param = params[:checkInType] # GET request
        check_in_param = params.dig(:session, :check_in_type) if check_in_param.nil?
        check_in_param == 'preCheckIn'
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_enabled')
      end
    end
  end
end
