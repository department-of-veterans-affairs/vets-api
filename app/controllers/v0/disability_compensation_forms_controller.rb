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

    # Submission path for `form526 increase only`
    # TODO: This is getting deprecated in favor of `form526 all claims` (defined below)
    #       and can eventually be removed completely
    def submit
      form_content = JSON.parse(request.body.string)
      saved_claim = SavedClaim::DisabilityCompensation::Form526IncreaseOnly.from_hash(form_content)
      saved_claim.save ? log_success(saved_claim) : log_failure(saved_claim)
      submission = Form526Submission.create_submission(@current_user, auth_headers, saved_claim)
      jid = submission.start(EVSS::DisabilityCompensationForm::SubmitForm526IncreaseOnly)

      render json: { data: { attributes: { job_id: jid } } },
             status: :ok
    rescue => e
      binding.pry
    end

    # :nocov:
    def submit_all_claim
      # TODO: While testing `all claims` submissions we will be merging the submission
      # with a hard coded "completed" form which will gap fill any missing data. This should
      # be removed before `all claims` goes live.
      form_content = JSON.parse(request.body.string)
      saved_claim = SavedClaim::DisabilityCompensation::Form526AllClaim.from_hash(form_content)
      saved_claim.save ? log_success(saved_claim) : log_failure(saved_claim)
      submission = Form526Submission.create_submission(@current_user, auth_headers, saved_claim)
      jid = submission.start(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim)

      render json: { data: { attributes: { job_id: jid } } },
             status: :ok
    end
    # :nocov:

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

    # :nocov:
    def all_claims_integration(form)
      test_form = JSON.parse(File.read(Settings.evss.all_claims_submission))

      # `deep_merge` will recursively replace any key values that have been included
      # in the submitted form
      test_form.deep_merge(form)
    end
    # :nocov:

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
