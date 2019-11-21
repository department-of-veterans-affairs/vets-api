# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class LimitsController < ApplicationController
    def index
      response = systems_service.get_facility_limits(
        current_user,
        limit_params[:facility_id],
        limit_params[:type_of_care_id]
      )

      render json: VAOS::LimitSerializer.new(response)
    end

    private

    def systems_service
      VAOS::SystemsService.new
    end

    def limit_params
      params.require(:facility_id)
      params.require(:type_of_care_id)
      params.permit(
        :facility_id,
        :type_of_care_id
      )
    end
  end
end
