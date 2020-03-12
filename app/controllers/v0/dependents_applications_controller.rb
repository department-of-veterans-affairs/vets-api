# frozen_string_literal: true

module V0
  class DependentsApplicationsController < ApplicationController
    def create
      dependent_service = BGS::DependentService.new
      bgsResponse = dependent_service.modify_dependents(current_user)
      render json: bgsResponse
    end

    def show
      dependent_service = BGS::DependentService.new
      dependents = dependent_service.get_dependents(current_user)
      render json: dependents, serializer: DependentsSerializer
    rescue => e
      log_exception_to_sentry(e)
      raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)
    end

    def disability_rating
      res = EVSS::Dependents::RetrievedInfo.for_user(current_user)
      render json: { has30_percent: res.body.dig('submitProcess', 'application', 'has30Percent') }
    end
  end
end
