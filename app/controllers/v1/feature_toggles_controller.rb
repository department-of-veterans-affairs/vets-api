# frozen_string_literal: true

module V1
  class FeatureTogglesController < ApplicationController
    skip_before_action :authenticate
    before_action :load_user

    def index
      render json: {
        data: {
          type: 'feature_toggles',
          features: factory.list
        }
      }
    end

    private

    def factory
      @factory ||=
        FeatureToggles::Factory.build(
          user: @current_user,
          cookie_id: params[:cookie_id],
          features: params[:features]
        )
    end
  end
end
