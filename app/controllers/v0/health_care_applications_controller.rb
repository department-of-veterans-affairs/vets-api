# frozen_string_literal: true
module V0
  class HealthCareApplicationsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      health_care_application = params[:form]

      if health_care_application
        render(json: { success: true })
      else
        render(json: { success: false })
      end
    end
  end
end
