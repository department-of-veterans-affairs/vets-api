# frozen_string_literal: true

module CheckIn
  module V2
    class PatientCheckInsController < CheckIn::ApplicationController
      def show
        check_in_session = CheckIn::V2::Session.build(data: { uuid: params[:id] }, jwt: session[:jwt])

        unless check_in_session.authorized?
          render json: check_in_session.unauthorized_message, status: :unauthorized and return
        end

        resp = ::V2::Lorota::Service.build(check_in: check_in_session).check_in_data

        render json: resp
      end

      def create
        check_in_session =
          CheckIn::V2::Session.build(data: { uuid: patient_check_in_params[:uuid] }, jwt: session[:jwt])

        resp =
          if check_in_session.authorized?
            ::V2::Chip::Service.build(check_in: check_in_session, params: patient_check_in_params).create_check_in
          else
            check_in_session.unauthorized_message
          end

        render json: resp
      end

      private

      def patient_check_in_params
        params.require(:patient_check_ins).permit(:uuid, :appointment_ien)
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_enabled')
      end
    end
  end
end
