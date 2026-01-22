# frozen_string_literal: true

require 'dependents/monitor'

module V0
  class DependentsApplicationsController < ApplicationController
    service_tag 'dependent-change'

    def show
      dependents = create_dependent_service.get_dependents
      dependents[:diaries] = dependency_verification_service.read_diaries
      render json: DependentsSerializer.new(dependents)
    rescue => e
      monitor.track_event(:error, e.message, 'dependents_controller.show_error')
      raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)
    end

    def create
      claim = create_claim(dependent_params.to_json)

      monitor.track_create_attempt(claim, current_user)

      # Populate the form_start_date from the IPF if available
      in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
      claim.form_start_date = in_progress_form.created_at if in_progress_form

      unless claim.save
        monitor.track_create_validation_error(in_progress_form, claim, current_user)
        log_validation_error_to_metadata(in_progress_form, claim)
        raise Common::Exceptions::ValidationErrors, claim
      end

      claim.process_attachments!

      dependent_service = create_dependent_service

      dependent_service.submit_686c_form(claim)

      log_submitted(in_progress_form, claim)
      claim.send_submitted_email(current_user)

      # clear_saved_form(claim.form_id) # We do not want to destroy the InProgressForm for this submission
      render json: SavedClaimSerializer.new(claim)
    rescue => e
      monitor.track_create_error(in_progress_form, claim, current_user, e)
      raise e
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
        :statement_of_truth_signature,
        :statement_of_truth_certified,
        'view:selectable686_options': {},
        dependents_application: {},
        supporting_documents: []
      )
    end

    # Creates a new claim instance with the provided form parameters.
    #
    # @param form_params [String] The JSON string for the claim form.
    # @return [Claim] A new instance of the claim class initialized with the given attributes.
    #   If the current user has an associated user account, it is included in the claim attributes.
    def create_claim(form_params)
      claim_attributes = { form: form_params }
      claim_attributes[:user_account] = @current_user.user_account if @current_user&.user_account

      SavedClaim::DependencyClaim.new(**claim_attributes)
    end

    ##
    # Include validation error on in_progress_form metadata.
    # `noop` if in_progress_form is `blank?`
    #
    # @param in_progress_form [InProgressForm]
    # @param claim [SavedClaim::DependencyClaim]
    #
    # @return [void]
    def log_validation_error_to_metadata(in_progress_form, claim)
      return if in_progress_form.blank?

      metadata = in_progress_form.metadata || {}
      metadata['submission'] ||= {}
      metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
      in_progress_form.update(metadata:)
    end

    def log_submitted(in_progress_form, claim)
      monitor.track_create_success(in_progress_form, claim, current_user)
      if claim.pension_related_submission?
        monitor.track_pension_related_submission(form_id: claim.form_id, form_type: claim.claim_form_type)
      end
    end

    def create_dependent_service
      @dependent_service ||= BGS::DependentService.new(current_user)
    end

    def dependency_verification_service
      @dependency_verification_service ||= BGS::DependencyVerificationService.new(current_user)
    end

    def stats_key
      'api.dependents_application'
    end

    def monitor(claim_id = nil)
      @monitor ||= Dependents::Monitor.new(claim_id)
    end
  end
end
