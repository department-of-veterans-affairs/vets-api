# frozen_string_literal: true

module VAOS
  class CCSupportedSitesController < VAOS::BaseController
    
    def show
      response = cc_supported_sites_service.get_supported_sites(params[:site_codes])
      render json: VAOS::CCSupportedSitesSerializer.new(response[:data], meta: response[:meta])
    end

    private

    def cc_supported_sites_service
      VAOS::CCSupportedSitesService.new(current_user)
    end
  end
end
