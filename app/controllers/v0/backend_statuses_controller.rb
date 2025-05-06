# frozen_string_literal: true

require 'lighthouse/benefits_education/service'
require 'backend_services'

module V0
  class BackendStatusesController < ApplicationController
    service_tag 'maintenance-windows'
    skip_before_action :authenticate

    def index
      options = { params: { maintenance_windows: } }
      render json: BackendStatusesSerializer.new(backend_statuses, options)
    end

    private

    # NOTE: Data is from PagerDuty
    def backend_statuses
      @backend_statuses ||= ExternalServicesRedis::Status.new.fetch_or_cache
    end

    def maintenance_windows
      @maintenance_windows ||= MaintenanceWindow.end_after(Time.zone.now)
    end
  end
end
