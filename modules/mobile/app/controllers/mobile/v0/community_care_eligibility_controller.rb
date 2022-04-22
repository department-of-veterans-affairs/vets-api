# frozen_string_literal: true

module Mobile
  module V0
    class CommunityCareEligibilityController < ApplicationController
      def show
        response = cce_service.get_eligibility(params[:service_type])
        render json: Mobile::V0::CommunityCareEligibilitySerializer.new(response[:data])
      end

      private

      def cce_service
        VAOS::CCEligibilityService.new(@current_user)
      end
    end
  end
end
