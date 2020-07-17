# frozen_string_literal: true

module VAOS
  module V0
    class RequestEligibilityCriteriaController < VAOS::V0::BaseController
      def index
        response = systems_service.get_request_eligibility_criteria(get_params[:site_codes])
        render json: VAOS::V0::RequestEligibilityCriteriaSerializer.new(response)
      end

      private

      def get_params
        params[:site_codes].is_a?(Array) ? params.permit(site_codes: []) : params.permit(:site_codes)
      end

      def systems_service
        VAOS::SystemsService.new(current_user)
      end
    end
  end
end
