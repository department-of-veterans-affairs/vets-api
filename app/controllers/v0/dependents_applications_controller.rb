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
      render(json: DependentsApplication.find(params[:id]))
    end

    def disability_rating
      res = EVSS::Dependents::RetrievedInfo.for_user(current_user)
      render json: { has30_percent: res.body.dig('submitProcess', 'application', 'has30Percent') }
    end
  end
end
