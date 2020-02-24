# frozen_string_literal: true

module V0
  class DependentsApplicationsController < ApplicationController
    def create
      dependents_application = DependentsApplication.new(
        params.require(:dependents_application).permit(:form).merge(
          user: current_user
        )
      )

      unless dependents_application.save
        Raven.tags_context(validation: 'dependents')

        raise Common::Exceptions::ValidationErrors, dependents_application
      end

      clear_saved_form(DependentsApplication::FORM_ID)

      render(json: dependents_application)
    end

    def show
      dependent_service = BGS::DependentService.new
      response = dependent_service.get_dependents(current_user)
      render json: response, each_serializer: DependentsSerializer
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
