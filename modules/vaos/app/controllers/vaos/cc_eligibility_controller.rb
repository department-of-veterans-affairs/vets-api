# frozen_string_literal: true

module VAOS
  class CCEligibilityController < ApplicationController

    def show
      response = cce_service.get_eligibility(params[:service_type])
      render json: VAOS::CCEligibilitySerializer.new(response)
    end

    private

    def cce_service
      VAOS::CCEligibilityService.new(current_user)
    end

  end
end
