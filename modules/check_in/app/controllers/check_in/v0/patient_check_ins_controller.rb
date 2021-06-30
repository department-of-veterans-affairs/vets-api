# frozen_string_literal: true

module CheckIn
  module V0
    class PatientCheckInsController < CheckIn::ApplicationController
      def show
        data = service.get_check_in(params[:id])

        render json: Oj.dump(data)
      end

      def create
        data = service.create_check_in(patient_check_in_params.to_h)

        render json: Oj.dump(data)
      end

      private

      def patient_check_in_params
        params.require(:patient_check_ins).permit(:id)
      end

      def service
        ChipApi::Service.build
      end
    end
  end
end
