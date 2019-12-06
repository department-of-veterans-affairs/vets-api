# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class FacilitiesController < ApplicationController
    def index
      response = systems_service.get_facilities(facilities_params)
      render json: VAOS::FacilitySerializer.new(response)
    end

    private

    def systems_service
      VAOS::SystemsService.new(current_user)
    end

    def facilities_params
      params.require(:facility_codes)
    end
  end
end
