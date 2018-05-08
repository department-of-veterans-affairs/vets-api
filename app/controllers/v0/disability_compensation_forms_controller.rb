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
      response = service.submit_form(request.body.string)
      render json: response,
             serializer: SubmitDisabilityFormSerializer
    end

    private

    def service
      EVSS::DisabilityCompensationForm::Service.new(@current_user)
    end
  end
end
