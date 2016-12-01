# frozen_string_literal: true
module V0
  class HealthCareApplicationsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      health_care_application = params[:form]

      if health_care_application.submit
        render json: { success: true, confirmation: health_care_application.confirmation_id }
      else 
        render json: { success: false }
      end
    end

    def index
      render json: { greeting: 'Hi there' }
    end
  end
end
