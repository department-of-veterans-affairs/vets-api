# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
module VAOS
  module V0
    class PactController < VAOS::V0::BaseController
      def index
        response = systems_service.get_system_pact(system_id)
        render json: VAOS::V0::SystemPactSerializer.new(response)
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
end
# :nocov:
