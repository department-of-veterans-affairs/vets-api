# frozen_string_literal: true

module VAOS
  class CCEligibilityController < ApplicationController
    def index
      response = cce_service.get_service_types
      render json: VAOS::CCEServiceTypesSerializer.new(response)
    end

    def show
      response = cce_service.get_eligibility(service_type)
      response.eligible
    end

    private

    def cce_service
      VAOS::CCEService.new(current_user)
    end

    def service_type
      params.require(:service_type)
    end
  end
end
