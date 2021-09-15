# frozen_string_literal: true

module CheckIn
  module V1
    class PatientCheckInsController < CheckIn::ApplicationController
      def show
        check_in = CheckIn::PatientCheckIn.build(uuid: params[:id])
        resp =
          if session[:jwt].present?
            ::V1::Lorota::Service.build(check_in: check_in).get_check_in
          else
            ::V1::Lorota::BasicService.build(check_in: check_in).get_check_in
          end

        render json: resp
      end

      def create
        check_in = CheckIn::PatientCheckIn.build(uuid: patient_check_in_params[:uuid])
        resp =
          if session[:jwt]
            ::V1::Chip::Service.build(check_in).create_check_in
          else
            { data: { error: true, message: 'Check-in failed' }, status: 403 }
          end

        render json: resp
      end

      private

      def patient_check_in_params
        params.require(:patient_check_ins).permit(:uuid)
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_low_authentication_enabled')
      end
    end
  end
end
