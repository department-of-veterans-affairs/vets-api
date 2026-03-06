# frozen_string_literal: true

require 'claims_evidence_api/uploader'
require 'dependents/monitor'
require 'digital_forms_api/service/submissions'

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

    def create # rubocop:disable Metrics/MethodLength
      claim = create_claim(dependent_params.to_json)

      @monitor = monitor(claim.id)

      @monitor.track_create_attempt(claim, current_user)
      @monitor.track_no_ssn_claims(form_id: claim.form_id, type: 'created') if claim.no_ssn_claim?

      # Populate the form_start_date from the IPF if available
      in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
      claim.form_start_date = in_progress_form.created_at if in_progress_form

      unless claim.save
        @monitor.track_create_validation_error(in_progress_form, claim, current_user)
        log_validation_error_to_metadata(in_progress_form, claim)
        raise Common::Exceptions::ValidationErrors, claim
      end

      claim.process_attachments!

      # FDF pilot
      forms_api_enabled = Flipper.enabled?(:dependents_digital_forms_api_submission_enabled, current_user)
      if forms_api_enabled && (claim.claim_form_type == '21-686c')
        begin
          claim_info = claim.get_claim_information(current_user)
          if claim_info[:proc_state] == 'MANUAL_VAGOV' && claim_info[:participant_id].present?
            submission = submit_via_forms_api(claim, claim_info[:claim_label], claim_info[:participant_id])
            log_submitted(in_progress_form, claim)
            claim.send_submitted_email(current_user)

            response = SavedClaimSerializer.new(claim).serializable_hash
            response[:data][:digital_forms_api] = { submission: }

            return render json: response
          end
        rescue => e
          @monitor.track_event(:error, e.message, 'dependents_controller.forms_api_submission', { error: e })
        end
      end

      dependent_service = create_dependent_service

      dependent_service.submit_686c_form(claim)

      log_submitted(in_progress_form, claim)
      claim.send_submitted_email(current_user)

      # clear_saved_form(claim.form_id) # We do not want to destroy the InProgressForm for this submission
      render json: SavedClaimSerializer.new(claim)
    rescue => e
      @monitor.track_create_error(in_progress_form, claim, current_user, e)
      raise e
    end

    private

    # submit claim to forms api - temp for FDF pilot
    def submit_via_forms_api(claim, claim_label, participant_id)
      digital_forms_api_submission_service ||= DigitalFormsApi::Service::Submissions.new

      payload = claim.parsed_form
      metadata = {
        formId: claim.claim_form_type,
        veteranId: participant_id,
        claimantId: participant_id,
        epCode: claim_label[/^\d+/],
        claimLabel: claim_label
      }

      response = digital_forms_api_submission_service.submit(payload, metadata)
      raise response.to_s unless response.success?

      @monitor.track_event(:info, 'success', 'dependents_controller.forms_api_submission', { claim:, response: })

      upload_evidence_documents(claim, participant_id)

      response.body['submission'] || {}
    end

    # upload evidence documents - temp for FDF pilot
    def upload_evidence_documents(claim, participant_id)
      form_id = claim.claim_form_type
      doctype = claim.document_type

      folder_identifier = "VETERAN:PARTICIPANT_ID:#{participant_id}"
      claims_evidence_uploader = ClaimsEvidenceApi::Uploader.new(folder_identifier)

      file_path = claim.process_pdf(claim.to_pdf(form_id:), claim.created_at, form_id)
      claims_evidence_uploader.upload_evidence(claim.id, file_path:, form_id:, doctype:)

      stamp_set = [{ text: 'VA.GOV', x: 5, y: 5 }]
      claim.persistent_attachments.each do |pa|
        doctype = pa.document_type
        file_path = PDFUtilities::PDFStamper.new(stamp_set).run(pa.to_pdf, timestamp: pa.created_at)
        claims_evidence_uploader.upload_evidence(claim.id, pa.id, file_path:, form_id:, doctype:)
      end
    rescue
      @monitor.track_event(:error, 'Evidence submission during Forms API processing failed',
                           "#{STATS_KEY}.submit_pdf.failure", error: e.message)
    end

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
      @monitor.track_create_success(in_progress_form, claim, current_user)
      if claim.pension_related_submission?
        @monitor.track_pension_related_submission(form_id: claim.form_id, form_type: claim.claim_form_type)
      end
      monitor.track_no_ssn_claims(form_id: claim.form_id, type: 'submitted') if claim.no_ssn_claim?
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
