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
      # Once we run this job asynchronosuly, this data translation can be moved into the
      # async `perform` method
      form_content = JSON.parse(request.body.string)
      uploads = form_content['form526'].delete('attachments')
      converted_form_content = EVSS::DisabilityCompensationForm::DataTranslation.new(
        @current_user, form_content
      ).translate
      response = service.submit_form(converted_form_content)
      EVSS::IntentToFile::ResponseStrategy.delete("#{@current_user.uuid}:compensation")
      unless uploads.empty?
        EVSS::DisabilityCompensationForm::SubmitUploads.start(@current_user, response.claim_id, uploads)
      end
      render json: response,
             serializer: SubmitDisabilityFormSerializer
    end

    private

    def service
      EVSS::DisabilityCompensationForm::Service.new(@current_user)
    end
  end
end
