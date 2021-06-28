# frozen_string_literal: true

module V1
  class FeatureTogglesController < ApplicationController
    skip_before_action :authenticate
    before_action :load_user

    def index
      list =
        Rails.cache.fetch(bundle.redis_key, expires_in: 5.minutes, skip_nil: true) do
          bundle.fetch
        end

      render json: { data: { type: 'feature_toggles', features: list } }
    end

    private

    def bundle
      @bundle ||=
        FeatureToggles::Bundle.build(
          user: @current_user,
          cookie_id: params[:cookie_id],
          features: params[:features]
        )
    end
  end
end
