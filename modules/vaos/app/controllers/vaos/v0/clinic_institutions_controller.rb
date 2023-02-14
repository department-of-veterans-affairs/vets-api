# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
module VAOS
  module V0
    class ClinicInstitutionsController < VAOS::V0::BaseController
      def index
        response = systems_service.get_clinic_institutions(
          system_id,
          clinic_ids
        )

        render json: VAOS::V0::ClinicInstitutionSerializer.new(response)
      end

      private

      def systems_service
        VAOS::SystemsService.new(current_user)
      end

      def system_id
        params.require(:system_id)
      end

      def clinic_ids
        params.require(:clinic_ids)
      end
    end
  end
end
# :nocov:
