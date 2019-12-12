# frozen_string_literal: true

module VAOS
  class CCEligibilityController < ApplicationController
    def index
      response = cce_service.get_service_types
      render json: VAOS::CCEligibilityServiceTypesSerializer.new(response)
    end

    def show
      response = cce_service.get_eligibility(service_type)
      response.eligible # what is response really going to look like, and still debating sending everything or just eligible flag
    end

    private

    def cce_service
      VAOS::CCEligibilityService.new(current_user)
    end

    def service_type
      params.require(:service_type)
    end
  end
end
