# frozen_string_literal: true

module V0
  class ServiceStatusesController < ApplicationController
    def index
      statuses = ExternalServicesRedis::Status.new.fetch_or_cache

      render json: statuses, serializer: ServiceStatusesSerializer
    end
  end
end
