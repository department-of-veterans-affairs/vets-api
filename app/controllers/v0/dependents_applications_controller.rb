# frozen_string_literal: true

module V0
  class DependentsApplicationsController < ApplicationController
    def create
      claim = SavedClaim::DependencyClaim.new(form: dependent_params.to_json)

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Raven.tags_context(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      claim.process_attachments!
      dependent_service.submit_686c_form(claim)

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      clear_saved_form(claim.form_id)

      render(json: claim)
    end

    def show
      dependents = dependent_service.get_dependents
      render json: dependents, serializer: DependentsSerializer
    rescue => e
      log_exception_to_sentry(e)
      raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)
    end

    def disability_rating
      res = EVSS::Dependents::RetrievedInfo.for_user(current_user)
      render json: { has30_percent: res.body.dig('submitProcess', 'application', 'has30Percent') }
    end

    private

    def dependent_params
      params.permit(
        :add_spouse,
        :veteran_was_married_before,
        :add_child,
        :report674,
        :report_divorce,
        :spouse_was_married_before,
        :report_stepchild_not_in_household,
        :report_death,
        :report_marriage_of_child_under18,
        :report_child18_or_older_is_not_attending_school,
        'view:selectable686_options': {},
        dependents_application: {},
        supporting_documents: []
      )
    end

    def dependent_service
      @dependent_service ||= BGS::DependentService.new(current_user)
    end

    def stats_key
      'api.dependents_application'
    end
  end
end
