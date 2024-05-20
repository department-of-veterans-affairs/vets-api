# frozen_string_literal: true

module V0
  class VeteranOnboardingsController < ApplicationController
    service_tag 'veteran-onboarding'
    before_action :set_veteran_onboarding

    def show
      render json: @veteran_onboarding, status: :ok
    end

    def update
      if @veteran_onboarding.update(veteran_onboarding_params)
        render json: @veteran_onboarding, status: :ok
      else
        render json: { errors: @veteran_onboarding.errors }, status: :unprocessable_entity
      end
    end

    private

    def set_veteran_onboarding
      @veteran_onboarding = current_user.onboarding
    end

    def veteran_onboarding_params
      params.require(:veteran_onboarding).permit(:display_onboarding_flow)
    end
  end
end
