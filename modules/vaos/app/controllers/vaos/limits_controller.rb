# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class LimitsController < VAOS::BaseController
    def index
      response = systems_service.get_facility_limits(
        facility_id,
        type_of_care_id
      )

      render json: VAOS::LimitSerializer.new(response)
    end

    private

    def systems_service
      VAOS::SystemsService.new(current_user)
    end

    def facility_id
      params.require(:facility_id)
    end

    def type_of_care_id
      params.require(:type_of_care_id)
    end
  end
end
