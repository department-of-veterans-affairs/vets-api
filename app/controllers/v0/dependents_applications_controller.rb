# frozen_string_literal: true

module V0
  class DependentsApplicationsController < ApplicationController
    def create
      params_hash = dependent_params.to_h
      bgs_response = bgs_dependent_service.modify_dependents(params_hash)
      render json: bgs_response
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

    def dependent_params
      params.permit(
        :add_child,
        :add_spouse,
        :report_divorce,
        :report_death,
        :report_stepchild_not_in_household,
        :report_marriage_of_child_under18,
        :report_child18_or_older_is_not_attending_school,
        :report674,
        :privacy_agreement_accepted,
        children_to_add: [],
        veteran_address: {},
        veteran_information: {},
        more_veteran_information: {},
        dependents_application: {}
      )
    end
  end
end
