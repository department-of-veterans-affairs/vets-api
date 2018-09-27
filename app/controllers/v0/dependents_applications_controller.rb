# frozen_string_literal: true

module V0
  class DependentsApplicationsController < ApplicationController
    skip_before_action(:authenticate)
    before_action(:tag_rainbows)

    def create
      dependents_application = DependentsApplication.new(
        params.require(:dependents_application).permit(:form)
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
  end
end
