# frozen_string_literal: true

module VAOS
  module V2
    class CCEligibilityController < VAOS::BaseController
      def show
        response = cce_service.get_eligibility(params[:service_type])
        render json: VAOS::V2::CCEligibilitySerializer.new(response[:data], meta: response[:meta])
      end

      private

      def cce_service
        VAOS::CCEligibilityService.new(current_user)
      end
    end
  end
end
