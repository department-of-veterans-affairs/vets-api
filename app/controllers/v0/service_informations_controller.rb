# frozen_string_literal: true

module V0
  class ServiceInformationsController < ApplicationController
    before_action do
      authorize :emis, :access?
      authorize :evss, :access?
    end

    def show
      response = {
        service_periods: @current_user.military_information.service_periods,
        served_in_combat_zone: @current_user.military_information.post_nov111998_combat
      }
      render json: response, serializer: ServiceInformationSerializer
    end
  end
end
