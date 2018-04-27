# frozen_string_literal: true

module V0
  class MaintenanceWindowsController < ApplicationController
    skip_before_action :authenticate

    def index
      @maintenance_windows = MaintenanceWindow.end_after(Time.zone.now)

      render json: @maintenance_windows,
             each_serializer: MaintenanceWindowSerializer
    end
  end
end
