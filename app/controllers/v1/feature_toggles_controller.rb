# frozen_string_literal: true

module V1
  class FeatureTogglesController < ApplicationController
    skip_before_action :authenticate
    before_action :load_user

    def index
      list =
        FeatureToggles::Bundle.build(
          user: @current_user,
          cookie_id: params[:cookie_id],
          features: params[:features]
        )&.fetch

      render json: Oj.dump({ data: { type: 'feature_toggles', features: list } })
    end
  end
end
