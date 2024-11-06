# frozen_string_literal: true

module V0
  class BannersController < ApplicationController
    skip_before_action :authenticate

    def by_path
      path = params[:path]
      banner_type = params[:type]
      # Filter banners based on path and banner_type if both are provided
      banners = Banner.all
      # banners = banners.where('some_path_column = ?', path) if path.present?
      # banners = banners.where('alert_type = ?', banner_type) if banner_type.present?
      response = { banners: banners, path: path, banner_type: banner_type }
      render json: response
    end
  end
end
