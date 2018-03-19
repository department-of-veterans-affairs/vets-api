# frozen_string_literal: true

module V0
  class BackendStatusesController < ApplicationController

    skip_before_action :authenticate, only: [:show]

    # GET /v0/backend_status/:service
    def show
      @backend_service = params[:service]
      raise Common::Exceptions::RecordNotFound, @backend_service unless recognized_service?

      # get status
      be_status = BackendStatus.new(name: @backend_service)

      case @backend_service
      when BackendServices::GI_BILL_STATUS
        be_status.is_available = EVSS::GiBillStatus::Service.within_scheduled_uptime?
      else
        # default service is up!
        be_status.is_available = true
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
