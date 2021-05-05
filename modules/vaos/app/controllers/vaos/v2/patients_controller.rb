# frozen_string_literal: true

module VAOS
  module V2
    class PatientsController < VAOS::V0::BaseController
      def index
        response = patient_service.get_patient_appointment_metadata(
          patient_params[:clinical_service_id],
          patient_params[:facility_id],
          patient_params[:type]
        )

        render json: VAOS::V2::PatientAppointmentMetadataSerializer.new(response)
      end

      private

      def patient_service
        VAOS::V2::PatientsService.new(current_user)
      end

      def patient_params
        params.require(:clinical_service_id)
        params.require(:facility_id)
        params.require(:type)
        params
      end
    end
  end
end
