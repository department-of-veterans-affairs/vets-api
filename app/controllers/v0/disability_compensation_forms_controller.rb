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

      # TODO: While testing `all claims` submissions we will be merging the submission
      # with a hard coded "completed" form which will gap fill any missing data. This should
      # be removed before `all claims` goes live.
      form_content = all_claims_integration(form_content) if form_content.key?('form526AllClaims')

      # TODO: Once `all_claims` is finalized and the test form is removed, the form assignment will
      # need to be normalized from `form526` to whatever the finalized form id is
      claim = SavedClaim::DisabilityCompensation.new(form: form_content['form526'].to_json)
      claim.save ? log_success(claim) : log_failure(claim)

      uploads = form_content['form526'].delete('attachments')

      form4142 = translate_form4142(form_content) if form_content['form526']['form4142'].present?

      converted_form_content = EVSS::DisabilityCompensationForm::DataTranslation.new(
        @current_user, form_content
      ).translate

      jid = EVSS::DisabilityCompensationForm::SubmitForm526.perform_async(
        @current_user.uuid, auth_headers, claim.id, converted_form_content, form4142, uploads
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

    def log_failure(claim)
      StatsD.increment("#{stats_key}.failure")
      raise Common::Exceptions::ValidationErrors, claim
    end

    def log_success(claim)
      StatsD.increment("#{stats_key}.success")
      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
    end

    def translate_form4142(form_content)
      EVSS::DisabilityCompensationForm::Form4142.new(@current_user, form_content).translate
    end

    def all_claims_integration(form)
      form['form526'] = form.delete('form526AllClaims')

      test_form = JSON.parse(File.read(Settings.evss.all_claims_submission))

      # `deep_merge` will recursively replace any key values that have been included
      # in the submitted form
      test_form.deep_merge(form)
    end

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
