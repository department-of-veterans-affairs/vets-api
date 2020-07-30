# frozen_string_literal: true

module VAOS
  module V0
    class RequestEligibilityCriteriaController < VAOS::V0::BaseController
      def index
        response = systems_service.get_request_eligibility_criteria(
          site_codes: url_params[:site_codes],
          parent_sites: url_params[:parent_sites]
        )
        render json: VAOS::V0::RequestEligibilityCriteriaSerializer.new(response)
      end

      private

      def url_params
        params[:site_codes].is_a?(Array) ? params.permit(site_codes: []) : params.permit(:site_codes)
        params[:parent_sites].is_a?(Array) ? params.permit(parent_sites: []) : params.permit(:parent_sites)
        params
      end

      def systems_service
        VAOS::SystemsService.new(current_user)
      end
    end
  end
end
