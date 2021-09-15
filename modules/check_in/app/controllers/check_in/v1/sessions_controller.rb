# frozen_string_literal: true

module CheckIn
  module V1
    class SessionsController < CheckIn::ApplicationController
      def show
        check_in = CheckIn::PatientCheckIn.build(uuid: params[:id])
        resp =
          if session[:jwt].present?
            { data:
              { permissions: 'read.full', uuid: check_in.uuid, status: 'success', jwt: session[:jwt] },
              status: 200 }
          else
            ::V1::Lorota::BasicService.build(check_in: check_in).get_or_create_token
          end

        render json: resp
      end

      def create
        check_in = CheckIn::CheckInWithAuth.build(data: session_params)
        resp =
          if session[:jwt].present?
            { data:
              { permissions: 'read.full', uuid: check_in.uuid, status: 'success', jwt: session[:jwt] },
              status: 200 }
          else
            data = ::V1::Lorota::Service.build(check_in: check_in).get_or_create_token

            session[:jwt] = data.dig(:data, :jwt)
            data
          end

        render json: resp
      end

      private

      def session_params
        params.require(:session).permit(:uuid, :last4, :last_name)
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_low_authentication_enabled')
      end
    end
  end
end
