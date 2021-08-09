# frozen_string_literal: true

module CheckIn
  module V0
    class PatientCheckInsController < CheckIn::ApplicationController
      def show
        check_in = CheckIn::PatientCheckIn.build(uuid: params[:id])
        data = ChipApi::Service.build(check_in).get_check_in

        render json: data
      end

      def create
        check_in = CheckIn::PatientCheckIn.build(uuid: patient_check_in_params[:id])
        data = ChipApi::Service.build(check_in).create_check_in

        render json: data
      end

      private

      def patient_check_in_params
        params.require(:patient_check_ins).permit(:id)
      end
    end
  end
end
