# frozen_string_literal: true

require 'lighthouse/benefits_education/service'
require 'backend_services'

module V0
  class BackendStatusesController < ApplicationController
    service_tag 'maintenance-windows'
    skip_before_action :authenticate
    before_action :validate_service, only: [:show]

    # NOTE: this endpoint is somewhat misleading.  Index gets data from PagerDuty and
    # show only looks at GI bill scheduled downtime (and gets no data from PagerDuty)
    def index
      options = { params: { maintenance_windows: } }
      render json: BackendStatusesSerializer.new(backend_statuses, options)
    end

    # GET /v0/backend_statuses/:service
    def show
      render json: BackendStatusSerializer.new(backend_status)
    end

    private

    def backend_statuses
      @backend_statuses ||= ExternalServicesRedis::Status.new.fetch_or_cache
    end

    def maintenance_windows
      @maintenance_windows ||= MaintenanceWindow.end_after(Time.zone.now)
    end

    def backend_status
      @backend_status ||= BackendStatus.new(name: backend_service)
    end

    def backend_service
      params[:service]
    end

    def validate_service
      raise Common::Exceptions::RecordNotFound, backend_service unless recognized_service?
    end

    def recognized_service?
      BackendServices.all.include?(backend_service)
    end

    def backend_status_is_available
      backend_service == BackendServices::GI_BILL_STATUS
    end
  end
end
