# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
module VAOS
  module V0
    class CCSupportedSitesController < VAOS::V0::BaseController
      def index
        response = cc_supported_sites_service.get_supported_sites(get_params[:site_codes])
        render json: VAOS::V0::CCSupportedSitesSerializer.new(response[:data], meta: response[:meta])
      end

      private

      def get_params
        params.require(:site_codes)
        params.permit(site_codes: [])
      end

      def cc_supported_sites_service
        VAOS::CCSupportedSitesService.new(current_user)
      end
    end
  end
end
# :nocov:
