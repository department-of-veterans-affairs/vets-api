# frozen_string_literal: true

module V0
  class MaintenanceWindowsController < ApplicationController
    service_tag 'maintenance-windows'
    skip_before_action :authenticate

    def index
      @maintenance_windows = MaintenanceWindow.end_after(Time.zone.now)

      render json: MaintenanceWindowSerializer.new(@maintenance_windows)
    end
  end
end
