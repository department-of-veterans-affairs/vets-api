# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class SystemsController < ApplicationController
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
