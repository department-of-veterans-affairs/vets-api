# frozen_string_literal: true

module VAOS
  class PactController < VAOS::BaseController
    def index
      response = systems_service.get_system_pact(system_id)
      render json: VAOS::SystemPactSerializer.new(response)
    end

    private

    def systems_service
      VAOS::SystemsService.new(current_user)
    end

    def system_id
      params.require(:system_id)
    end
  end
end
