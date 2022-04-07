# frozen_string_literal: true

module CheckIn
  module V2
    class PreCheckInsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[show create], if: :additional_logging?
      after_action :after_logger, only: %i[show create], if: :additional_logging?

      def show
        pre_check_in_session = CheckIn::V2::Session.build(
          data: { uuid: params[:id], check_in_type: params[:checkInType] }, jwt: low_auth_token
        )

        unless pre_check_in_session.authorized?
          render json: pre_check_in_session.unauthorized_message, status: :unauthorized and return
        end

        resp = ::V2::Lorota::Service.build(check_in: pre_check_in_session).check_in_data

        render json: resp
      end

      def create
        pre_check_in_session = CheckIn::V2::Session.build(
          data: { uuid: permitted_params[:uuid], check_in_type: permitted_params[:check_in_type] },
          jwt: low_auth_token
        )

        unless pre_check_in_session.authorized?
          render json: pre_check_in_session.unauthorized_message, status: :unauthorized and return
        end

        resp = ::V2::Chip::Service.build(check_in: pre_check_in_session, params: permitted_params).pre_check_in

        render json: resp
      end

      def permitted_params
        params.require(:pre_check_in).permit(:uuid, :demographics_up_to_date, :next_of_kin_up_to_date,
                                             :emergency_contact_up_to_date, :check_in_type)
      end

      private

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_pre_check_in_enabled')
      end
    end
  end
end
