# frozen_string_literal: true

module VAOS
  class InstitutionsController < VAOS::BaseController
    def index
      response = systems_service.get_clinic_institutions(
        system_id,
        clinic_ids
      )

      render json: VAOS::InstitutionSerializer.new(response)
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
