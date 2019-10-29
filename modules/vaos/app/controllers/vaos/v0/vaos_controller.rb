# frozen_string_literal: true

module VAOS
  module V0
    class VAOSController < ApplicationController
      before_action { authorize :vaos, :access? }

      def get_systems
        response = systems_service.get_systems(current_user)
        render json: VAOS::SystemSerializer.new(response)
      end

      private

      def systems_service
        VAOS::SystemsService.new
      end
    end
  end
end
