# frozen_string_literal: true

module V0
  class DependentsApplicationsController < ApplicationController
    service_tag 'dependent-change'

    def show
      dependents = dependent_service.get_dependents
      dependents[:diaries] = dependency_verification_service.read_diaries
      render json: DependentsSerializer.new(dependents)
    rescue => e
      log_exception_to_sentry(e)
      raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)
    end

    def create
      if Flipper.enabled?(:va_dependents_v2, current_user)
        form = dependent_params.to_json
        use_v2 = form.present? ? JSON.parse(form)&.dig('dependents_application', 'use_v2') : nil
        claim = SavedClaim::DependencyClaim.new(form:, use_v2:)
      else
        claim = SavedClaim::DependencyClaim.new(form: dependent_params.to_json)
      end

      # Populate the form_start_date from the IPF if available
      in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
      claim.form_start_date = in_progress_form.created_at if in_progress_form

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Sentry.set_tags(team: 'vfs-ebenefits') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end

      claim.process_attachments!
      dependent_service.submit_686c_form(claim)

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
      claim.send_submitted_email(current_user) if Flipper.enabled?(:dependents_submitted_email)

      # clear_saved_form(claim.form_id) # We do not want to destroy the InProgressForm for this submission

      render json: SavedClaimSerializer.new(claim)
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

    def dependency_verification_service
      @dependency_verification_service ||= BGS::DependencyVerificationService.new(current_user)
    end

    def stats_key
      'api.dependents_application'
    end
  end
end
