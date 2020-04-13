# frozen_string_literal: true

module VAOS::V0
  class SystemsController < VAOS::V0::BaseController
    def index
      # response = systems_service.get_systems
      # render json: VAOS::SystemSerializer.new(response)
      render json: { a: 'funk' }.to_json
    end

    private

    def systems_service
      VAOS::SystemsService.new(current_user)
    end
  end
end
