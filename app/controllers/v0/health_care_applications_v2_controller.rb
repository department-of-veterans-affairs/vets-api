# frozen_string_literal: true

module V0
  class HealthCareApplicationsV2Controller < ApplicationController
    include HcaValidate

    def create
      authenticate_token

      form = JSON.parse(params[:form])
      validate!(form)

      health_care_application = HealthCareApplication.create!

      HCA::SubmissionJob.perform_async(current_user&.uuid, form, health_care_application.id)
      clear_saved_form(HcaValidate::FORM_ID)

      render(json: health_care_application)
    end

    def show
      render(json: HealthCareApplication.find(params[:id]))
    end
  end
end
