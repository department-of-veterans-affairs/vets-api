# frozen_string_literal: true

module V0
  class DisabilityCompensationFormsController < ApplicationController
    before_action { authorize :evss, :access? }
    before_action :validate_name_part, only: [:suggested_conditions]

    def rated_disabilities
      response = service.get_rated_disabilities
      render json: response,
             serializer: RatedDisabilitiesSerializer
    end

    def suggested_conditions
      results = DisabilityContention.suggested(params[:name_part])
      render json: results, each_serializer: DisabilityContentionSerializer
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
        @current_user.uuid, auth_headers, claim.id, converted_form_content, uploads
      )

      render json: { data: { attributes: { job_id: jid } } },
             status: :ok
    end

    def submission_status
      submission = AsyncTransaction::EVSS::VA526ezSubmitTransaction.find_transaction(params[:job_id])
      raise Common::Exceptions::RecordNotFound, params[:job_id] unless submission
      render json: submission, serializer: AsyncTransaction::BaseSerializer
    end

    private

    def validate_name_part
      raise Common::Exceptions::ParameterMissing, 'name_part' if params[:name_part].blank?
    end

    def service
      EVSS::DisabilityCompensationForm::Service.new(auth_headers)
    end

    def auth_headers
      EVSS::DisabilityCompensationAuthHeaders.new(@current_user).add_headers(EVSS::AuthHeaders.new(@current_user).to_h)
    end

    def stats_key
      'api.disability_compensation'
    end
  end
end
