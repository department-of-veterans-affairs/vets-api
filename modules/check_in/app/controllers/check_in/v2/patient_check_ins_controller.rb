# frozen_string_literal: true

module CheckIn
  module V2
    class PatientCheckInsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[show create]
      after_action :after_logger, only: %i[show create]

      def show
        check_in_session = CheckIn::V2::Session.build(data: { uuid: params[:id], handoff: handoff? },
                                                      jwt: low_auth_token)

        unless check_in_session.authorized?
          render json: check_in_session.unauthorized_message, status: :unauthorized and return
        end

        patient_check_in_data = ::V2::Lorota::Service.build(check_in: check_in_session).check_in_data

        if Flipper.enabled?('check_in_experience_45_minute_reminder')
          if start_check_in_called?(patient_check_in_data)
            params[:set_e_checkin_started_called] = true
          else
            ::V2::Chip::Service.build(check_in: check_in_session).set_echeckin_started
            params[:set_e_checkin_started_called] = false
          end
        end

        render json: patient_check_in_data
      end

      def create
        check_in_session =
          CheckIn::V2::Session.build(data: { uuid: permitted_params[:uuid] }, jwt: low_auth_token)

        resp =
          if check_in_session.authorized?
            ::V2::Chip::Service.build(check_in: check_in_session, params: permitted_params).create_check_in
          else
            check_in_session.unauthorized_message
          end

        render json: resp
      end

      def permitted_params
        params.require(:patient_check_ins).permit(:uuid, :appointment_ien, :set_e_checkin_started_called,
                                                  :is_travel_enabled, :travel_submitted)
      end

      private

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_enabled')
      end

      def handoff?
        params[:handoff]&.downcase == 'true'
      end

      def start_check_in_called?(patient_check_in_data)
        patient_check_in_data.dig(:payload, :setECheckinStartedCalled)
      end
    end
  end
end
