# frozen_string_literal: true
module V0
  class HealthCareApplicationsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      health_care_application = params[:form]
      puts health_care_application
      render json: { success: true, confirmation: 13}
    end

    def index
      render json: { greeting: 'Hi there' }
    end
  end
end
