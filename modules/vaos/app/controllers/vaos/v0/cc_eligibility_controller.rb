# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
module VAOS
  module V0
    class CCEligibilityController < VAOS::V0::BaseController
      def show
        response = cce_service.get_eligibility(params[:service_type])
        render json: VAOS::V0::CCEligibilitySerializer.new(response[:data], meta: response[:meta])
      end

      private

      def cce_service
        VAOS::CCEligibilityService.new(current_user)
      end
    end
  end
end
# :nocov:
