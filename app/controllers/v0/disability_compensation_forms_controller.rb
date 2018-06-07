# frozen_string_literal: true

module V0
  class DisabilityCompensationFormsController < ApplicationController
    before_action { authorize :evss, :access? }

    def rated_disabilities
      response = service.get_rated_disabilities
      render json: response,
             serializer: RatedDisabilitiesSerializer
    end

    def submit
      form_content = JSON.parse(request.body.string)
      converted_form_content = EVSS::DataTranslation.new(@current_user, form_content).convert
      response = service.submit_form(converted_form_content)
      EVSS::DisabilityCompensationForm::SubmitUploads.start(@current_user, response.claim_id)
      render json: response,
             serializer: SubmitDisabilityFormSerializer
    end

    private

    def service
      EVSS::DisabilityCompensationForm::Service.new(@current_user)
    end
  end
end
