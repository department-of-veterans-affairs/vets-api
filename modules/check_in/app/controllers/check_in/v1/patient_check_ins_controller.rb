# frozen_string_literal: true

module CheckIn
  module V1
    class PatientCheckInsController < CheckIn::ApplicationController
      def show; end

      def create
        check_in = CheckIn::PatientCheckIn.build(uuid: patient_check_in_params[:id])
        data = ::V1::Chip::Service.build(check_in).create_check_in

        render json: data
      end

      private

      def patient_check_in_params
        params.require(:patient_check_ins).permit(:id)
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_low_authentication_enabled')
      end
    end
  end
end
