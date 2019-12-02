# frozen_string_literal: true

module VAOS
  class LimitsController < ApplicationController
    def index
      response = systems_service.get_facility_limits(
        current_user,
        facility_id,
        type_of_care_id
      )

      render json: VAOS::LimitSerializer.new(response)
    end

    private

    def systems_service
      VAOS::SystemsService.new
    end

    def facility_id
			params.require(:facility_id)
    end

    def type_of_care_id
      params.require(:type_of_care_id)
    end
  end
end
