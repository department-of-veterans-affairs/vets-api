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
      jid = EVSS::DisabilityCompensationForm::SubmitForm.start(@current_user, request.body.string)
      logger.info('submit form start', user: user.uuid, component: 'EVSS', form: '21-526EZ', jid: jid)
      head 200
    end

    private

    def service
      EVSS::DisabilityCompensationForm::Service.new(@current_user)
    end
  end
end
