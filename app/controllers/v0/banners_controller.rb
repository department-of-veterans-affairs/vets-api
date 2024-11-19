# frozen_string_literal: true

module V0
  class BannersController < ApplicationController
    service_tag 'banners'
    skip_before_action :authenticate

    def by_path
      # Default to 'full_width_banner_alert' banner (bundle) type.
      banner_type = params.fetch(:type, 'full_width_banner_alert')
      path = params[:path]
      render json: { banners: [] } unless path.present?
     
      banners = Banner.where(entity_bundle: banner_type).by_path(path)
      response = { banners: banners, path: path, banner_type: banner_type }
      render json: response
    end
  end
end
