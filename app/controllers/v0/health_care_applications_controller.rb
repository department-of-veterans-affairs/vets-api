# frozen_string_literal: true
require 'hca/service'

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

    def healthcheck
      service = HCA::Service.new
      render(json: service.health_check)
    end
  end
end
