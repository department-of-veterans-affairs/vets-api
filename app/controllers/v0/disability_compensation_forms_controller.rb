# frozen_string_literal: true

module V0
  class DisabilityCompensationFormsController < ApplicationController
    before_action { authorize :evss, :access? }
    before_action :validate_name_part, only: [:suggested_conditions]

    def find_rating_info_pid
      rating_info_service = EVSS::DisabilityCompensationForm::ServiceRatingInfo.new(auth_headers)
      response = rating_info_service.get_rating_info
      render json: response,
             serializer: RatingInfoSerializer
    end

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
      submission = create_submission(saved_claim)
      jid = submission.start(EVSS::DisabilityCompensationForm::SubmitForm526IncreaseOnly)

      render json: { data: { attributes: { job_id: jid } } },
             status: :ok
    end

    def submit_all_claim
      form_content = JSON.parse(request.body.string)
      saved_claim = SavedClaim::DisabilityCompensation::Form526AllClaim.from_hash(form_content)
      saved_claim.save ? log_success(saved_claim) : log_failure(saved_claim)
      submission = create_submission(saved_claim)

      jid = submission.start(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim)

      render json: { data: { attributes: { job_id: jid } } },
             status: :ok
    end

    def submission_status
      job_status = Form526JobStatus.where(job_id: params[:job_id]).first
      raise Common::Exceptions::RecordNotFound, params[:job_id] unless job_status

      render json: job_status, serializer: Form526JobStatusSerializer
    end

    private

    def create_submission(saved_claim)
      Rails.logger.info(
        'Creating 526 submission', user_uuid: @current_user&.uuid, saved_claim_id: saved_claim&.id
      )
      Form526Submission.create(
        user_uuid: @current_user.uuid,
        saved_claim_id: saved_claim.id,
        auth_headers_json: auth_headers.to_json,
        form_json: saved_claim.to_submission_data(@current_user)
      )
    rescue PG::NotNullViolation => e
      Rails.logger.error(
        'Creating 526 submission: PG::NotNullViolation', user_uuid: @current_user&.uuid, saved_claim_id: saved_claim&.id
      )
      raise e
    end

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
