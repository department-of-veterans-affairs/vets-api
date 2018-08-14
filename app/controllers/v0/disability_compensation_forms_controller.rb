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

      claim = SavedClaim::DisabilityCompensation.new(form: form_content['form526'].to_json)
      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        raise Common::Exceptions::ValidationErrors, claim
      end
      StatsD.increment("#{stats_key}.success")
      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"

      uploads = form_content['form526'].delete('attachments')
      converted_form_content = EVSS::DisabilityCompensationForm::DataTranslation.new(
        @current_user, form_content
      ).translate

      jid = EVSS::DisabilityCompensationForm::SubmitForm526.perform_async(
        @current_user, converted_form_content, uploads
      )

      render json: { job_id: jid },
             status: :accepted
    end

    private

    def service
      EVSS::DisabilityCompensationForm::Service.new(@current_user)
    end

    def stats_key
      'api.disability_compensation'
    end
  end
end
