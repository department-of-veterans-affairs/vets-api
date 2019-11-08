# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class ClinicsController < ApplicationController
    def index
      response = systems_service.get_facility_clinics(
        current_user, params[:facility_id], params[:type_of_care_id], params[:system_id]
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
      params.require(:system_id)
      params.permit(
        :facility_id,
        :type_of_care_id,
        :system_id
      )
    end
  end
end
