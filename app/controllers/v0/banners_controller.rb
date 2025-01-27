# frozen_string_literal: true

module V0
  class BannersController < ApplicationController
    service_tag 'banners'
    skip_before_action :authenticate

    def by_path
      # Default to 'full_width_banner_alert' banner (bundle) type.
      banner_type = params.fetch(:type, 'full_width_banner_alert')
      return render json: { error: 'Path parameter is required' }, status: :unprocessable_entity if path.blank?

      banners = Banner.where(entity_bundle: banner_type).by_path(path)
      render json: { banners:, path:, banner_type: }
    end

    private

    def path
      params[:path]
    end
  end
end
