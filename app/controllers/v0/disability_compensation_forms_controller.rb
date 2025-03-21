# frozen_string_literal: true

require 'evss/common_service'
require 'evss/disability_compensation_auth_headers'
require 'evss/disability_compensation_form/form4142'
require 'evss/disability_compensation_form/service'
require 'lighthouse/benefits_reference_data/response_strategy'
require 'disability_compensation/factories/api_provider_factory'

module V0
  class DisabilityCompensationFormsController < ApplicationController
    service_tag 'disability-application'
    before_action(except: :rating_info) { authorize :evss, :access? }
    before_action :auth_rating_info, only: [:rating_info]
    before_action :validate_name_part, only: [:suggested_conditions]

    def rated_disabilities
      invoker = 'V0::DisabilityCompensationFormsController#rated_disabilities'
      api_provider = ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:rated_disabilities],
        provider: :lighthouse,
        options: { icn: @current_user.icn.to_s, auth_headers: },
        current_user: @current_user,
        feature_toggle: nil
      )

      response = api_provider.get_rated_disabilities(nil, nil, { invoker: })

      render json: RatedDisabilitiesSerializer.new(response)
    end

    def separation_locations
      response = Lighthouse::ReferenceData::ResponseStrategy.new.cache_by_user_and_type(
        :all_users,
        :get_separation_locations
      ) do
        # A separate provider is needed in order to interact with LH Staging and test BRD e2e properly
        # We use vsp_environment here as RAILS_ENV is set to 'production' in staging
        provider = Settings.vsp_environment == 'staging' ? :lighthouse_staging : :lighthouse
        api_provider = ApiProviderFactory.call(
          type: ApiProviderFactory::FACTORIES[:brd],
          provider:,
          options: {},
          current_user: @current_user,
          feature_toggle: nil
        )
        api_provider.get_separation_locations
      end
      render json: SeparationLocationSerializer.new(response)
    end

    def suggested_conditions
      results = DisabilityContention.suggested(params[:name_part])
      render json: DisabilityContentionSerializer.new(results)
    end

    def submit_all_claim
      temp_separation_location_fix if Flipper.enabled?(:disability_compensation_temp_separation_location_code_string,
                                                       @current_user)

      saved_claim = SavedClaim::DisabilityCompensation::Form526AllClaim.from_hash(form_content)
      saved_claim.save ? log_success(saved_claim) : log_failure(saved_claim)
      submission = create_submission(saved_claim)
      # if jid = 0 then the submission was prevented from going any further in the process
      jid = 0

      # Feature flag to stop submission from being submitted to third-party service
      # With this on, the submission will NOT be processed by EVSS or Lighthouse,
      # nor will it go to VBMS,
      # but the line of code before this one creates the submission in the vets-api database
      if Flipper.enabled?(:disability_compensation_prevent_submission_job, @current_user)
        Rails.logger.info("Submission ID: #{submission.id} prevented from sending to third party service.")
      else
        jid = submission.start
      end

      render json: { data: { attributes: { job_id: jid } } },
             status: :ok
    end

    def submission_status
      job_status = Form526JobStatus.where(job_id: params[:job_id]).first
      raise Common::Exceptions::RecordNotFound, params[:job_id] unless job_status

      render json: Form526JobStatusSerializer.new(job_status)
    end

    def rating_info
      if lighthouse?
        service = LighthouseRatedDisabilitiesProvider.new(@current_user.icn)

        disability_rating = service.get_combined_disability_rating

        rating_info = { user_percent_of_disability: disability_rating }
        render json: LighthouseRatingInfoSerializer.new(rating_info)
      else
        rating_info_service = EVSS::CommonService.new(auth_headers)
        response = rating_info_service.get_rating_info

        render json: RatingInfoSerializer.new(response)
      end
    end

    private

    def auth_rating_info
      api = lighthouse? ? :lighthouse : :evss
      authorize(api, :rating_info_access?)
    end

    def form_content
      @form_content ||= JSON.parse(request.body.string)
    end

    def lighthouse?
      Flipper.enabled?(:profile_lighthouse_rating_info, @current_user)
    end

    def create_submission(saved_claim)
      Rails.logger.info('Creating 526 submission', user_uuid: @current_user&.uuid, saved_claim_id: saved_claim&.id)
      submission = Form526Submission.new(
        user_uuid: @current_user.uuid,
        user_account: @current_user.user_account,
        saved_claim_id: saved_claim.id,
        auth_headers_json: auth_headers.to_json,
        form_json: saved_claim.to_submission_data(@current_user),
        submit_endpoint: 'claims_api'
      ) { |sub| sub.add_birls_ids @current_user.birls_id }

      if missing_disabilities?(submission)
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: 'no new or increased disabilities were submitted', source: 'DisabilityCompensationFormsController'
        )
      end

      submission.save! && submission
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

    def validate_name_part
      raise Common::Exceptions::ParameterMissing, 'name_part' if params[:name_part].blank?
    end

    def auth_headers
      EVSS::DisabilityCompensationAuthHeaders.new(@current_user).add_headers(EVSS::AuthHeaders.new(@current_user).to_h)
    end

    def stats_key
      'api.disability_compensation'
    end

    def missing_disabilities?(submission)
      if submission.form['form526']['form526']['disabilities'].none?
        StatsD.increment("#{stats_key}.failure")
        Rails.logger.error(
          'Creating 526 submission: no new or increased disabilities were submitted', user_uuid: @current_user&.uuid
        )
        return true
      end
      false
    end

    # TEMPORARY
    # Turn separation location into string
    # 11/18/2024 BRD EVSS -> Lighthouse migration caused separation location to turn into an integer,
    # while SavedClaim (vets-json-schema) is expecting a string
    def temp_separation_location_fix
      if form_content.is_a?(Hash) && form_content['form526'].is_a?(Hash)
        separation_location_code = form_content.dig('form526', 'serviceInformation', 'separationLocation',
                                                    'separationLocationCode')
        unless separation_location_code.nil?
          form_content['form526']['serviceInformation']['separationLocation']['separationLocationCode'] =
            separation_location_code.to_s
        end
      end
    end
    # END TEMPORARY
  end
end
