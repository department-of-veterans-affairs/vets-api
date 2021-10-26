# frozen_string_literal: true

require 'evss/gi_bill_status/service'
require 'backend_services'

module V0
  class BackendStatusesController < ApplicationController
    skip_before_action :authenticate

    # NOTE: this endpoint is somewhat misleading.  Index gets data from PagerDuty and
    # show only looks at GI bill scheduled downtime (and gets no data from PagerDuty)
    def index
      statuses = ExternalServicesRedis::Status.new.fetch_or_cache

      render json: statuses, serializer: BackendStatusesSerializer
    end

    # GET /v0/backend_statuses/:service
    def show
      @backend_service = params[:service]
      raise Common::Exceptions::RecordNotFound, @backend_service unless recognized_service?

      # get status
      be_status = BackendStatus.new(name: @backend_service)
      case @backend_service
      when BackendServices::GI_BILL_STATUS
        be_status.is_available = EVSS::GiBillStatus::Service.within_scheduled_uptime?
        be_status.uptime_remaining = EVSS::GiBillStatus::Service.seconds_until_downtime
      else
        # default service is up!
        be_status.is_available = true
        be_status.uptime_remaining = 0
      end

      render json: be_status,
             serializer: BackendStatusSerializer
    end

    private

    def recognized_service?
      BackendServices.all.include?(@backend_service)
    end
  end
end
