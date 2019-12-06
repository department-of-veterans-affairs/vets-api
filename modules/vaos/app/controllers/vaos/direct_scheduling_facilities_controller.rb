# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class DirectSchedulingFacilitiesController < ApplicationController
    def index
      response = systems_service.get_system_facilities(
        facilities_params[:system_id],
        facilities_params[:parent_code],
        facilities_params[:type_of_care_id]
      )

      render json: VAOS::DirectSchedulingFacilitySerializer.new(response)
    end

    private

    def systems_service
      VAOS::SystemsService.new(current_user)
    end

    def facilities_params
      params.require(%i[parent_code system_id type_of_care_id])
      params.permit(
        :parent_code,
        :system_id,
        :type_of_care_id
      )
    end
  end
end
