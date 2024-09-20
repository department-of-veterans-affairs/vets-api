# frozen_string_literal: true

require 'lighthouse/benefits_education/service'
require 'backend_services'

module V0
  class BackendStatusesController < ApplicationController
    service_tag 'maintenance-windows'
    skip_before_action :authenticate

    # NOTE: this endpoint is somewhat misleading.  Index gets data from PagerDuty and
    # show only looks at GI bill scheduled downtime (and gets no data from PagerDuty)
    def index
      statuses = ExternalServicesRedis::Status.new.fetch_or_cache
      maintenance_windows = MaintenanceWindow.end_after(Time.zone.now)

      options = { params: { maintenance_windows: } }
      render json: BackendStatusesSerializer.new(statuses, options)
    end

    # TO-DO: After transition of Post-911 GI Bill to 24/7 availability, confirm show action
    # can be completely removed
    # 
    # GET /v0/backend_statuses/:service
    def show
      @backend_service = params[:service]
      raise Common::Exceptions::RecordNotFound, @backend_service unless recognized_service?

      # default service is up
      be_status = BackendStatus.new(name: @backend_service, is_available: true, uptime_remaining: 0)

      # case where 24/7 access is disabled for post-911 GI bill
      if (@backend_service == BackendServices::GI_BILL_STATUS) && !Flipper.enabled?(:sob_updated_design)
        be_status.is_available = BenefitsEducation::Service.within_scheduled_uptime?
        be_status.uptime_remaining = BenefitsEducation::Service.seconds_until_downtime
      end
   
      render json: BackendStatusSerializer.new(be_status)
    end

    private

    def recognized_service?
      BackendServices.all.include?(@backend_service)
    end
  end
end
