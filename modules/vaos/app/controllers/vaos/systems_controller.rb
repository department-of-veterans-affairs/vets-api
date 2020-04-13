# frozen_string_literal: true

module VAOS
  class SystemsController < VAOS::BaseController
    def index
      response = systems_service.get_systems
      render json: VAOS::SystemSerializer.new(response)
    end

    private

    def systems_service
      VAOS::SystemsService.new(current_user)
    end
  end
end
