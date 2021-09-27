# frozen_string_literal: true

module CheckIn
  module V2
    class PatientCheckInsController < CheckIn::ApplicationController
      def show
        head :not_implemented
      end

      def create
        head :not_implemented
      end

      private

      def patient_check_in_params
        params.require(:patient_check_ins).permit(:uuid)
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_multiple_appointment_support')
      end
    end
  end
end
