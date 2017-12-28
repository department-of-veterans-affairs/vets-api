# frozen_string_literal: true
module V0
  class MaintenanceWindowsController < ApplicationController
    skip_before_action :authenticate

    def index
      @maintenance_windows = MaintenanceWindow.all

      render json: @maintenance_windows
    end
  end
end
