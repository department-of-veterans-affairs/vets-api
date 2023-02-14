# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
module VAOS
  module V0
    class DirectBookingEligibilityCriteriaController < VAOS::V0::BaseController
      def index
        response = systems_service.get_direct_booking_elig_crit(
          site_codes: url_params[:site_codes],
          parent_sites: url_params[:parent_sites]
        )
        render json: VAOS::V0::DirectBookingEligibilityCriteriaSerializer.new(response)
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
# :nocov:
