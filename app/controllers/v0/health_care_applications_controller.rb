# frozen_string_literal: true
require 'hca/service'

module V0
  class HealthCareApplicationsController < ApplicationController
    skip_before_action(:authenticate)

    def create
      service.submit_form(params[:form])
      render(json: { success: true })
    end

    def healthcheck
      render(json: service.health_check)
    end

    private

    def service
      HCA::Service.new
    end
  end
end
