# frozen_string_literal: true

module VAOS
  module V0
    class SystemsController < VAOS::V0::BaseController
      def index
        response = systems_service.get_systems
        render json: VAOS::V0::SystemSerializer.new(response)
      end

      private

      def systems_service
        VAOS::SystemsService.new(current_user)
      end
    end
  end
end
