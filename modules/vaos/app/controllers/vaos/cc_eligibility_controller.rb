# frozen_string_literal: true

module VAOS
  class CCEligibilityController < VAOS::BaseController
    def show
      response = cce_service.get_eligibility(params[:service_type])
      render json: VAOS::CCEligibilitySerializer.new(response[:data], meta: response[:meta])
    end

    private

    def cce_service
      VAOS::CCEligibilityService.for_user(current_user)
    end
  end
end
