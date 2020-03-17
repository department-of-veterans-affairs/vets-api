# frozen_string_literal: true

module V0
  class DependentsApplicationsController < ApplicationController
    def create
      bgsResponse = bgs_dependent_service.modify_dependents
      render json: bgsResponse
    end

    def show
      dependents = bgs_dependent_service.get_dependents
      render json: dependents, serializer: DependentsSerializer
    rescue => e
      log_exception_to_sentry(e)
      raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)
    end

    def disability_rating
      res = EVSS::Dependents::RetrievedInfo.for_user(current_user)
      render json: { has30_percent: res.body.dig('submitProcess', 'application', 'has30Percent') }
    end

    private

    def bgs_dependent_service
      @bgs_dependent_service ||= BGS::DependentService.new(current_user)
    end
  end
end
