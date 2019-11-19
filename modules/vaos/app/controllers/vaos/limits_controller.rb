# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class LimitsController < ApplicationController
    def index
      response = systems_service.get_facility_clinics(
        current_user,
        clinics_params[:facility_id],
        clinics_params[:type_of_care_id]
      )

      render json: VAOS::ClinicSerializer.new(response)
    end

    private

    def systems_service
      VAOS::SystemsService.new
    end

    def clinics_params
      params.require(:facility_id)
      params.require(:type_of_care_id)
      params.permit(
        :facility_id,
        :type_of_care_id
      )
    end
  end
end
