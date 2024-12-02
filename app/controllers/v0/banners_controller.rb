# frozen_string_literal: true

module V0
  class BannersController < ApplicationController
    service_tag 'banners'
    skip_before_action :authenticate

    def by_path
      path = params[:path]
      # Default to 'full_width_banner_alert' banner (bundle) type.
      banner_type = params.fetch(:type, 'full_width_banner_alert')
      banners = []
      banners = Banner.by_path_and_type(path, banner_type) if path && banner_type
      response = { banners: banners, path: path, banner_type: banner_type }
      render json: response
    end
  end
end
