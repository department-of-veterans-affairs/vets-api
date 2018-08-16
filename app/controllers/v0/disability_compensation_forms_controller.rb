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
      # Once we run this job asynchronously, this data translation can be moved into the
      # async `perform` method
      form_content = JSON.parse(request.body.string)
      uploads = form_content['form526'].delete('attachments')
      converted_form_content = EVSS::DisabilityCompensationForm::DataTranslation.new(
        @current_user, form_content
      ).translate
      response = service.submit_form(converted_form_content)
      EVSS::IntentToFile::ResponseStrategy.delete("#{@current_user.uuid}:compensation")
      if uploads.present?
        EVSS::DisabilityCompensationForm::SubmitUploads.start(@current_user, response.claim_id, uploads)
      end
      render json: response,
        serializer: SubmitDisabilityFormSerializer
    end

    def submission_status
      submission = AsyncTransaction::EVSS::VA526ezSubmitTransaction.find_transaction(params[:job_id])
      if submission
        {
          status: submission.status,
          response: submission.response
        }.to_json
      end
    end

    def user_submissions
      submissions = AsyncTransaction::EVSS::VA526ezSubmitTransaction.find_transactions(@current_user)
      submissions.map do |submission|
        {
          status: submission.status,
          response: submission.response
        }
      end
    end

    private

    def service
      EVSS::DisabilityCompensationForm::Service.new(@current_user)
    end
  end
end
